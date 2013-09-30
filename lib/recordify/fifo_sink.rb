require "mkfifo"
# 'Hallon::Fifo' merged with Plaything

class FifoSink
  Error = Class.new(StandardError)
  Formats = {
      [ :int16, 1 ] => :mono16,
      [ :int16, 2 ] => :stereo16,
  }

  attr_accessor :format, :output

  def initialize(fifo_path, format = {sample_rate: 44100, sample_type: :int16, channels: 2})
    @buffer = Array.new
    @playing, @stopped = false
    @buffer_size = 44100 * 4 # overridden by format=

    @output = fifo_path
    File.delete(@output) if File.exists?(@output)
    File.mkfifo(@output) # Will error if it's overwriting another file

    @monitor = Monitor.new
    self.format = format
  end

  def format=(format)
    synchronize do
      if @playing
        stop
      end

      @sample_type = format.fetch(:sample_type)
      @sample_rate = Integer(format.fetch(:sample_rate))
      @channels = Integer(format.fetch(:channels))

      @sample_format = Formats.fetch([@sample_type, @channels]) do
        raise TypeError, "unknown sample format for type [#{@sample_type}, #{@channels}]"
      end

      # 44100 int16s = 22050 frames = 0.5s (1 frame * 2 channels = 2 int16 = 1 sample = 1/44100 s)
      @buffer_size = @sample_rate * @channels * 1.0
    end
  end

  def output=(new_output)
    old_output, @output = @output, new_output

    File.delete(old_output)
    File.delete(new_output) if File.exists?(new_output)
    File.mkfifo(new_output)
  end

  def drops
    # This SHOULD return the number of times the queue "stuttered"
    # However, it ain't easy to do this with only knowledge of the fifo pipe.
    0
  end

  def pause
    @playing = false
  end

  def play
    @playing = true
    @stopped = false
  end

  def stop
    @stopped = true
    @stream_thread.exit if @stream_thread

    @buffer.clear
  end

  def reset
    self.output = @output
  end

  def stream(frames, frame_format)
    synchronize do
      self.format = frame_format if frame_format != format

      queue = File.new(@output, "wb")

      # Get the next block from Spotify.
      audio_data = frames.take(@buffer_size)

      if audio_data.nil? # Audio format has changed, reset buffer.
        @buffer.clear
                         # TODO signal to reader that audio format has changed
      else
        @buffer += audio_data
        begin
          queue.syswrite packed_samples(@buffer)
        rescue Errno::EPIPE
          self.reset
        end
        @buffer.clear
      end

      ensure_playing

      @buffer_size / 2
    end
  end

  private

  def packed_samples(frames)
    frames.flatten.map { |i| [i].pack("s_") }.join
  end

  def ensure_playing
    play unless @playing
  end

  def synchronize
    @monitor.synchronize { return yield }
  end
end
