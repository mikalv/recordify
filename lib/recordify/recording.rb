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
    $logger.info "track #{id}: #{message}\n"
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
    log "Move PCM tmp #{source_path} -> #{tmp_file_path}"
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
    log "Link track into #{folder}"
    FileUtils.symlink(file_path, folder)
  end

  def convert
    log 'start conversion'
    puts `sox -r 44100 -c 2 -t s16 #{tmp_file_path} -C 256 #{file_path}`
    unless $?.success?
      raise 'Audio conversion failed'
    end
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
    puts `#{File.dirname(__FILE__)}/../../bin/upload.py #{file_path}`
    unless $?.success?
      raise 'Upload failed'
    end
    log 'upload finished'
  end
end
