class Spotify::Recorder

  def record(uri)
    @sink = FifoSink.new
  end

  def start(track)
    #
  end

  def finished(track)
    metadata = Metadata.load(track)

    # get metadata
    # write file
    # add to database
  end
end