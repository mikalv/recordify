#!/usr/bin/env ruby
require_relative '../lib/recordify'

raise "No spotify track URI given" if ARGV[0].nil?

appkey = ENV['SPOTIFY_APPKEY']
username = ENV['SPOTIFY_USERNAME']
password = ENV['SPOTIFY_PASSWORD']
track_uri = ARGV[0]
fifo = "spotify.fifo"

sink = FifoSink.new(fifo)
recordify = Recordify::Client.new(appkey, sink)
player = Recordify::Player.new(recordify)

recordify.connect(username, password)
$logger.info "Writing PCM stream to fifo #{fifo}"
fork do
  exec "play -r 44100 -c 2 -t s16 #{fifo}"
end
player.play(track_uri)
player.wait
