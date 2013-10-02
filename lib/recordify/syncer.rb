require 'taglib'
require 'fileutils'
require_relative 'recording'

SPOTIFY_HOME=ENV['SPOTIFY_HOME']
PCM_TMP_FILE="#{SPOTIFY_HOME}/tmp.pcm"
LOG_FILE="#{SPOTIFY_HOME}/recordify.log"

TRACKS="#{SPOTIFY_HOME}/tracks"
PLAYLISTS="#{SPOTIFY_HOME}/playlists"

class Recordify::Syncer
  attr_accessor :appkey, :username, :password, :recordify, :player

  def initialize
    @appkey ||= ENV['SPOTIFY_APPKEY']
    @username ||= ENV['SPOTIFY_USERNAME']
    @password ||= ENV['SPOTIFY_PASSWORD']

    @recordify = Recordify::Client.new(appkey, nil)
    @player = Recordify::Player.new(@recordify)
  end

  def setup
    [TRACKS, PLAYLISTS].each do |folder|
      if !Dir.exists?(folder)
        FileUtils.mkdir_p(folder)
      end
    end
  end

  def log(message)
    File.new(LOG_FILE, 'a').puts(message)
    $logger.info "#{message}"
  end

  def start
    log "Master started #{$$}"
    setup
    @recordify.connect(@username, @password)
    @recordify.sink = FileSink.new("#{PCM_TMP_FILE}")
  end

  def sync_playlist(playlist)
    # create playlist folder
    playlist_uri = @recordify.playlist_uri(playlist)
    playlist_id = playlist_uri.split(':')[4]
    playlist_dir = File.join(PLAYLISTS, playlist_id)
    playlist_name = Spotify.playlist_name(playlist)
    FileUtils.mkdir_p(playlist_dir)
    log "Start playlist sync [#{playlist_name}] #{playlist_id}"
    tracks = @recordify.tracks(playlist)
    tracks.values.each do |track|
      begin
        @recording = sync_track(track, playlist, playlist_id, playlist_dir)
      rescue Spotify::Error
        log "Spotify ERROR: Skipping #{@recordify.track_uri(track)}"
      end
    end
  end

  def sync(spotify_uri)
    playlist = @recordify.playlist(spotify_uri)
    sync_playlist(playlist)
  end

  def sync_all
    @playlists = @recordify.playlists
    @playlists.values.each do |playlist|
      sync_playlist(playlist)
    end
  end

  def sync_track(track, playlist, playlist_id, playlist_dir)
    @recording = Recordify::Recording.new(track)
    @recording.uri = @recordify.track_uri(track)
    @recording.metadata = @recordify.track_metadata(track)
    @recording.destination_folder = TRACKS
    @recording.source_path = @recordify.sink.output
    @recording.playlist = playlist
    @recording.playlist_dir = playlist_dir
    @recording.playlist_id = playlist_id

    if @recording.exits?
      log "Skip existing: #{@recording}"
    else
      log "Start sync: #{@recording}"
      # TODO move to recording class
      if File.exists?(@recording.source_path)
        log "Cleanup - remove existing PCM source #{@recording.source_path}"
        File.delete(@recording.source_path)
      end
      @player.play(@recording)
      @player.listen
      @recording.process
    end

    @recording
  end
end