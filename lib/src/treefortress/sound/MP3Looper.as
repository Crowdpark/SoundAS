package treefortress.sound
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SampleDataEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;
    import flash.media.SoundTransform;
    import flash.utils.ByteArray;

	/**
	 * @author antonstepanov
	 * @creation date Jun 18, 2013
	 */
	public class MP3Looper extends EventDispatcher
	{
		private const MAGIC_DELAY:Number = 2257.0; // LAME 3.98.2 + flash.media.Sound Delay
		private const BUFFER_SIZE:int = 4096; // Stable playback

		private var _source:Sound; // Use for decoding
		private var _output:Sound; // Use for output stream

		private var _channel:SoundChannel;

		private var _samplesPosition:int = 0;
		private var samplesTotal:int;

		private var currentPlayCount:int;
		public var enabled:Boolean = true; //start/stop playback

		public function MP3Looper(sourceMp3:Sound, autoPlay:Boolean = false)
		{
			_source = sourceMp3;
			init();
			super(null);
		}

		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		//SETTERS AND GETTERS
		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		public function get source():Sound
		{
			return _source;
		}

		public function get output():Sound
		{
			return _output;
		}

		public function get channel():SoundChannel
		{
			return _channel;
		}

        public function set volume(value:Number):void {
            if(_channel && _channel.soundTransform) {
                var transform:SoundTransform = _channel.soundTransform;
                transform.volume = value;
                _channel.soundTransform = transform;
            }
        }

		public function get isPlaying():Boolean
		{
			return Boolean(_channel);
		}

		public function get samplesPosition():int
		{
			return _samplesPosition;
		}

		public function set samplesPosition(samplesPosition:int):void
		{
			_samplesPosition = samplesPosition;
		}

		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		//PUBLIC FUNCTIONS
		//::::::::::::::::::::::::::::::::::::::::::::::::::::::

		/**
		 * start source playback
		 * count = -1 means loop infinitly
		 */
		public function play(count:int = 1):void
		{
			//reset current count

			currentPlayCount = count;
			startPlayback();
		}

		public function stop():void
		{
			stopPlayback();
		}


		public function update():void
		{
			samplesTotal = getTotalSamples();
		}

		public function getProgress():Number
		{
			return    samplesPosition / samplesTotal;
		}

		public function setProgress(progress:Number):void
		{
			samplesPosition = samplesTotal * progress;
		}

		public function dispose():void
		{

		}

		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		//PRIVATE FUNCTIONS
		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		private function init():void
		{
			_output = new Sound();
		}

		private function startPlayback():void
		{
			output.addEventListener(SampleDataEvent.SAMPLE_DATA, sampleData);
			update();
			_channel = output.play();
		}

		private function stopPlayback():void
		{
			output.removeEventListener(SampleDataEvent.SAMPLE_DATA, sampleData);
			dispatchEvent(new Event(Event.COMPLETE));
		}

		/**
		 * This methods extracts audio data from the mp3 and wraps it automatically with respect to encoder delay
		 *
		 * @param target The ByteArray where to write the audio data
		 * @param length The amount of samples to be read
		 */
		private function extract(target:ByteArray, length:int):void
		{
			// trace("MP3Loop.extract(",[ samplesPosition,getProgress()],")");
			while (0 < length)
			{
				// trace("MP3Loop.extract(",[samplesPosition,(samplesPosition + length), samplesTotal],")");
				if (samplesPosition + length > samplesTotal)
				{
					var read:int = samplesTotal - samplesPosition;
					source.extract(target, read, samplesPosition + MAGIC_DELAY);
					samplesPosition += read;
					length -= read;
				}
				else
				{
					source.extract(target, length, samplesPosition + MAGIC_DELAY);
					samplesPosition += length;
					length = 0;
				}
				if (samplesPosition == samplesTotal) // END OF LOOP > WRAP
				{

                    trace("[MP3Looper remaining loopcount]: " + currentPlayCount);
					currentPlayCount--;
					if (currentPlayCount <= 0)
					{
						length = 0;
						samplesPosition = 0;
						enabled = false;
						stopPlayback();
					}
					else
					{
						samplesPosition = 0;
					}
				}
			}
			// vo.progress=samplesPosition/samplesTotal;
		}

		private function silent(target:ByteArray, length:int):void
		{
			trace("MP3Loop.silent(", [ length], ")");
			target.position = 0;

			while (length--)
			{
				target.writeFloat(0.0);
				target.writeFloat(0.0);
			}
		}

		private function getTotalSamples():int
		{
			var magic:Number = 77.75;
			var len:Number = source.length - magic;
			return Math.floor((len / 1000) * 44100);
		}

		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		//EVENT HANDLERS
		//::::::::::::::::::::::::::::::::::::::::::::::::::::::
		private function sampleData(event:SampleDataEvent):void
		{
			// trace("MP3Loop.sampleData.enabled(",[enabled],")");
			if (enabled)
			{
				extract(event.data, BUFFER_SIZE);
			}
			else
			{
				silent(event.data, BUFFER_SIZE);
			}
		}
	}
}
