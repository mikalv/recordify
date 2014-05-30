class Recordify::Recording
  require 'fileutils'
  attr_accessor :converted, :uploaded, :id, :uri, :track, :playlist_id, :playlist,
                :metadata, :source_path, :destination_folder, :playlist_dir

  def initialize(track)
    @track = track
    @converted = false
    @uploaded = false
  end

  def log(message)
    $logger.info "#{message}: #{self.to_s}"
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
    "[#{metadata[:name]}] #{@id}"
  end

  def process
    log "Moving PCM source -> #{tmp_file_path}"
    FileUtils.mv(source_path, tmp_file_path)

    pid = fork do
      log "Worker #{$$} started"
      self.convert
      self.write_metadata
      #self.upload
      self.add_to_playlist(playlist_dir)
      exit 0
    end

    if ! pid.nil?
      log "Master #{$$} detach worker #{pid}"
      Process.detach(pid)
    end
  end

  def add_to_playlist(playlist_folder)
    playlist_name = Spotify.playlist_name(playlist)
    playlist_path = File.join(SPOTIFY_HOME, "playlists", "#{playlist_name}.m3u")
    log "Add to playlist #{playlist_path}"
    File.open(playlist_path, 'a+') do |f|
      f.puts "#{File.basename(file_path)}"
    end
  end

  def convert
    log "Start conversion -> #{file_path}"
    puts `sox -r 44100 -c 2 -t s16 #{tmp_file_path} -C 256 #{file_path}`
    unless $?.success?
      raise 'Audio conversion failed'
    end
    File.delete(tmp_file_path)
    @converted = true
    log "End conversion -> #{file_path}"
  end

  def write_metadata
    log 'Write metadata'
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
    puts `#{File.dirname(__FILE__)}/../../bin/upload.py #{file_path}`
    unless $?.success?
      raise "Upload failed #{self.to_s}"
    end
    log 'upload finished'
  end
end
