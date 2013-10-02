require 'json'

class Recordify::Player

  attr_accessor :recording

  def initialize(client)
    @client = client
  end

  def play(recording)
    @recording = recording
    $logger.info "Start playback: #{@recording}"
    Spotify.try(:session_player_load, @client.session, recording.track)
    $end_of_track = false
    Spotify.try(:session_player_play, @client.session, true)
    @recording
  end

  def play_uri(uri)
    link = Spotify.link_create_from_string(uri)
    track = Spotify.link_as_track(link)
    # TODO create a recording
    play(track)
  end

  def listen
    @client.poll { $end_of_track }
    Spotify.try(:session_player_play, @client.session, false)
    Spotify.try(:session_player_unload, @client.session)
    $logger.info "End playback: #{@recording}"
  end

  class FrameReader
    include Enumerable

    def initialize(channels, sample_type, frames_count, frames_ptr)
      @channels = channels
      @sample_type = sample_type
      @size = frames_count * @channels
      @pointer = FFI::Pointer.new(@sample_type, frames_ptr)
    end

    attr_reader :size

    def each
      return enum_for(__method__) unless block_given?
      ffi_read = :"read_#{@sample_type}"
      (0...size).each do |index|
        yield @pointer[index].public_send(ffi_read)
      end
    end
  end
end
