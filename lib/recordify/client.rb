require 'spotify'
require 'plaything'
require 'logger'
require_relative 'fifo_sink'

Thread.abort_on_exception = true
$logger = Logger.new($stderr)
$logger.level = Logger::INFO

class Recordify::Client
# FIXME bug in Plaything when releasing OpenAL context when disconnecting session
attr_accessor :config, :session, :playlist_container, :sink

  def initialize(appkey, sink)
    @callbacks = callbacks
    @appkey = appkey
    @config = create_session_config(@appkey, @callbacks)
    @debug = false
    @sink = sink
  end

  def debug?
    @debug
  end

  def debug!
    @debug = true
    $logger.level = Logger::DEBUG
  end

  def connect(username, password)
    login(username, password, @config)
    @playlist_container = load_playlist_container
  end

  def disconnect
    Spotify.session_logout(@session)
    poll { Spotify.session_connectionstate(@session) == :logged_out }
    # wait for logout to complete before freeing the resources
    Spotify.playlistcontainer_release(@playlist_container)
    Spotify.session_release(@session)
  end

  def login(username, password, config)
    $logger.info "Creating session."
    @session = create_session(config)
    $logger.info "Created! Logging in."
    Spotify.session_login(session, username, password, false, nil)
    $logger.info "Log in requested. Waiting forever until logged in."
    poll { Spotify.session_connectionstate(session) == :logged_in }
    $logger.info "Logged in as #{Spotify.session_user_name(session)}."
    session
  end

  def load_track(track_uri)
    link = Spotify.link_create_from_string(track_uri)
    if link.null?
      $logger.error "Invalid URI. Aborting."
      abort
    elsif (link_type = Spotify.link_type(link)) != :track
      $logger.error "Was #{link_type} URI. Needs track. Aborting."
      abort
    else
      track = Spotify.link_as_track(link)
    end
    $logger.info "Attempting to load track. Waiting forever until successful."
    poll { Spotify.track_is_loaded(track) }
    $logger.info "Track loaded."
    track
  end

  def load_track_metadata(track)
    track_attributes = {}
    [:num_artists, :album, :name, :duration, :disc, :index].each do |attr|
      track_attributes[attr] = Spotify.send("track_#{attr}".to_sym, track)
    end
    track_attributes[:artists] = []
    (1..track_attributes[:num_artists]+1).each do |artist_id|
      track_attributes[:artists] << Spotify.send(:track_artist, track, artist_id)
    end
    [:artist, :name, :year].each do |attr|
      puts Spotify.send("album_#{attr}".to_sym, track_attributes[:album]);
    end
    track_attributes
  end

  def link_uri(link)
    length = Spotify.link_as_string(link, nil, 0)
    FFI::Buffer.alloc_out(length + 1) do |b|
      Spotify.link_as_string(link, b, b.size)
      return b.get_string(0).force_encoding("UTF-8")
    end
  end

  def tracks_for_playlist(playlist)
    num_tracks = Spotify.playlist_num_tracks(playlist)
    tracks = {}
    (0..num_tracks-1).each do |num|
      track = Spotify.playlist_track(playlist, num)
      poll { Spotify.track_is_loaded(track) }
      link = Spotify.link_create_from_track(track, 0)
      uri = link_uri(link)
      name = Spotify.track_name(track)
      $logger.info("Track loaded: #{name}")
      tracks[name] = uri
    end
    tracks
  end

  def load_playlist_container
    playlist_container = Spotify.session_playlistcontainer(@session)
    poll { Spotify.playlistcontainer_is_loaded(playlist_container) }
    playlist_container
  end

  def load_playlist(uri)
    $logger.info("Load playlist: #{uri}")
    link = Spotify.link_create_from_string(uri)
    playlist = Spotify.playlist_create(@session, link)
    poll { Spotify.playlist_is_loaded(playlist) }
    playlist
  end

  def playlist(index)
    playlist = Spotify.playlistcontainer_playlist(@playlist_container, index)
    poll { Spotify.playlist_is_loaded(playlist) }
    link = Spotify.link_create_from_playlist(playlist)
    uri = link_uri(link)
    $logger.info("Playlist loaded: #{Spotify.playlist_name(playlist)} #{uri}")
    playlist
  end

  def playlists
    num_playlists = Spotify.playlistcontainer_num_playlists(@playlist_container)
    playlists = {}
    (0..num_playlists-1).each do |index|
      playlist = playlist(index)
      name = Spotify.playlist_name(playlist)
      playlists[name] = playlist
    end
    playlists
  end

  def create_session_config(appkey, callbacks)
    Spotify::SessionConfig.new(
        {
            api_version: Spotify::API_VERSION.to_i,
            application_key: IO.read(appkey, encoding: "BINARY"),
            cache_location: ".spotify/",
            settings_location: ".spotify/",
            user_agent: "spotify for ruby",
            callbacks: Spotify::SessionCallbacks.new(callbacks)
        })
  end

  def callbacks
    client = self
    {
        log_message: proc do |session, message|
          $logger.info("session (log message)") { message } if client.debug?
        end,

        logged_in: proc do |session, error|
          $logger.debug("session (logged in)") { Spotify::Error.explain(error) }
        end,

        logged_out: proc do |session|
          $logger.debug("session (logged out)") { "logged out!" }
        end,

        streaming_error: proc do |session, error|
          $logger.error("session (player)") { "streaming error %s" % Spotify::Error.explain(error) }
        end,

        start_playback: proc do |session|
          $logger.debug("session (player)") { "start playback" }
          client.sink.play
        end,

        stop_playback: proc do |session|
          $logger.debug("session (player)") { "stop playback" }
          client.sink.stop
        end,

        get_audio_buffer_stats: proc do |session, stats|
          stats[:samples] = client.sink.queue_size
          stats[:stutter] = client.sink.drops
          $logger.debug("session (player)") { "queue size [#{stats[:samples]}, #{stats[:stutter]}]" }
        end,

        music_delivery: proc do |session, format, frames, num_frames|
          if num_frames == 0
            $logger.debug("session (player)") { "music delivery audio discontuity" }
            client.sink.stop
            0
          else
            frames = Recordify::Player::FrameReader.new(format[:channels], format[:sample_type], num_frames, frames)
            consumed_frames = client.sink.stream(frames, format.to_h)
            $logger.debug("session (player)") { "music delivery #{consumed_frames} of #{num_frames}" }
            consumed_frames
          end
        end,

        end_of_track: proc do |session|
          $end_of_track = true
          $logger.debug("session (player)") { "end of track" }
          client.sink.stop
        end
    }
  end

  def poll
    session = @session
    until yield
      FFI::MemoryPointer.new(:int) do |ptr|
        Spotify.session_process_events(session, ptr)
      end
      sleep(0.1)
    end
  end

  def create_session(config)
    FFI::MemoryPointer.new(Spotify::Session) do |ptr|
      Spotify.try(:session_create, config, ptr)
      return Spotify::Session.new(ptr.read_pointer)
    end
  end
end