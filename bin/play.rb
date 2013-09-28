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
puts "Recording to fifo #{fifo}"
player.play(track_uri)
