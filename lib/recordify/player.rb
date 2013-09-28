require 'json'

class Recordify::Player
  def initialize(client)
    @client = client
  end

  def start_playback(track)
    $logger.info "Start playback: #{Spotify.track_name(track)}"
  end

  def end_playback(track)
    $logger.info "End playback: #{Spotify.track_name(track)}"
  end

  def play(uri)
    link = Spotify.link_create_from_string(uri)
    track = Spotify.link_as_track(link)
    @client.poll{ Spotify.track_is_loaded(track) }
    Spotify.try(:session_player_play, @client.session, false)
    start_playback(track)
    Spotify.try(:session_player_load, @client.session, track)
    Spotify.try(:session_player_play, @client.session, true)
    @client.poll { $end_of_track }
    end_playback(track)
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
