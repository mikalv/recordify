#!/usr/bin/env ruby
require 'fileutils'
require_relative '../lib/recordify'
require 'taglib'

HOME=ENV['SPOTIFY_HOME']
PCM_TMP_FILE="#{HOME}/tmp.pcm"
LOG_FILE="#{HOME}/recordify.log"
PLAYLIST_INDEX_NAME="tracks.txt"

TRACKS="#{HOME}/tracks"
PLAYLISTS="#{HOME}/playlists"

class Recording
  require 'fileutils'
  attr_accessor :converted, :uploaded, :id, :uri, :track, :playlist_id, :playlist,
                :metadata, :source_path, :destination_folder, :playlist_dir

  def initialize(track)
    @track = track
    @converted = false
    @uploaded = false
  end

  def log(message)
    $logger.debug "track #{id}: #{message}\n"
  end

  def uri=(spotify_uri)
    @uri = spotify_uri
    @id = spotify_uri.split(':')[2]
  end

  def base_path
    File.join(destination_folder, id)
  end

  def file_path
    "#{base_path}.mp3"
  end

  def tmp_file_path
    "#{base_path}.pcm"
  end

  def exits?
    File.exists?(file_path)
  end

  def to_s
    "#{metadata[:album][:name]} - #{metadata[:name]}:#{file_path}"
  end

  def process
    log "move #{source_path} -> #{tmp_file_path}"
    FileUtils.mv(source_path, tmp_file_path)

    pid = fork do
      self.convert
      self.write_metadata
      self.upload
      self.link(playlist_dir)
      exit 0
    end
    Process.detach(pid)
  end

  def link(folder)
    log "linking file"
    FileUtils.symlink(file_path, folder)
  end

  def convert
    log 'start conversion'
    system "sox -r 44100 -c 2 -t s16 #{tmp_file_path} -C 256 #{file_path}"
    File.delete(tmp_file_path)
    @converted = true
    log 'end conversion'
  end

  def write_metadata
    log 'writing metadata'
    TagLib::FileRef.open(file_path) do |fileref|
      unless fileref.null?
        tag = fileref.tag
        tag.title   = metadata[:name]
        tag.artist  = metadata[:album][:artist][:name]
        tag.album   = metadata[:album][:name]
        tag.year    = metadata[:album][:year]
        tag.track   = metadata[:index]
        tag.comment = uri
        fileref.save
      end
    end
  end

  def upload
    log 'uploading'
    system "#{File.dirname(__FILE__)}/upload.py #{file_path}"
  end
end

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
      if ! Dir.exists?(folder)
        FileUtils.mkdir_p(folder)
      end
    end
  end

  def log(message)
    File.new(LOG_FILE, 'a').puts(message)
    STDOUT.puts(message)
  end

  def start
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
    log "Syncing playlist[#{playlist_id}]: #{playlist_name}"
    tracks = @recordify.tracks(playlist)
    tracks.values.each do |track|
      @recording = sync_track(track, playlist, playlist_id, playlist_dir)
      File.new(File.join(playlist_dir, PLAYLIST_INDEX_NAME), 'a').puts(@recording.id)
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
    @recording = Recording.new(track)
    @recording.uri = @recordify.track_uri(track)
    @recording.metadata = @recordify.track_metadata(track)
    @recording.destination_folder = TRACKS
    @recording.source_path = @recordify.sink.output
    @recording.playlist = playlist
    @recording.playlist_dir = playlist_dir
    @recording.playlist_id = playlist_id

    if @recording.exits?
      log "Skipping existing recording #{@recording}"
    else
      log "Sync track: #{@recording}"
      @player.play_track(track)
      @player.listen_to_track
      @recording.process
    end

    @recording
  end
end

syncer = Recordify::Syncer.new
syncer.recordify.debug!
syncer.start
playlist_uri = ARGV[0]
if playlist_uri
  syncer.sync(playlist_uri)
else
  syncer.sync_all
end