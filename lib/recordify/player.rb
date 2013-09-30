require 'json'

class Recordify::Player

  attr_accessor :playing

  def initialize(client)
    @client = client
  end

  def play_track(track)
    @playing = track
    $logger.info "Start playback: #{@client.track_uri(@playing)}"
    Spotify.try(:session_player_load, @client.session, track)
    $end_of_track = false
    Spotify.try(:session_player_play, @client.session, true)
    @playing
  end

  def play(uri)
    link = Spotify.link_create_from_string(uri)
    track = Spotify.link_as_track(link)
    play_track(track)
  end

  def listen_to_track
    @client.poll { $end_of_track }
    #Spotify.try(:session_player_unload, @client.session)
    $logger.info "End playback: #{@client.track_uri(@playing)}"
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
