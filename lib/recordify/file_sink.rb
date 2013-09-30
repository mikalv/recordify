# 'Hallon::Fifo' merged with Plaything

class FileSink
  Error = Class.new(StandardError)
  Formats = {
      [ :int16, 1 ] => :mono16,
      [ :int16, 2 ] => :stereo16,
  }

  attr_accessor :format, :output, :stopped

  def initialize(file_path, format = {sample_rate: 44100, sample_type: :int16, channels: 2})
    @buffer = Array.new
    @playing, @stopped = false
    @buffer_size = 44100 # overridden by format=

    @output = file_path
    @monitor = Monitor.new
    self.format = format
  end

  # @return [Integer] total size of current play queue.
  def queue_size
    @buffer.size
  end

  def format=(format)
    synchronize do
      if ! @stopped && @playing
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

  def end_of_track
  end

  def format_changed?(new_format)
    return true if new_format[:sample_type] != @sample_type
    return true if new_format[:sample_type] != @sample_type
    return true if new_format[:channels] != @channels
    return false
  end

  def stream(frames, frame_format)
    # TODO ensure buffer is written even on $end_of_track ?
    synchronize do
      #STDOUT.syswrite '.'
      self.format = frame_format if format_changed?(frame_format)
      audio_data = frames.take(@buffer_size)
      queue = File.new(@output, 'ab')
      if audio_data.nil?
        @buffer.clear
      else
        @buffer = audio_data
        queue.syswrite packed_samples(@buffer)
        @buffer.clear
      end

      @buffer_size / 2
    end
  end

  private

  def packed_samples(frames)
    frames.flatten.map { |i| [i].pack("s_") }.join
  end

  def synchronize
    @monitor.synchronize { return yield }
  end
end
