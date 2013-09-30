#!/usr/bin/env ruby
require_relative '../lib/recordify'
require 'taglib'

raise "No spotify track URI given" if ARGV[0].nil?

appkey = ENV['SPOTIFY_APPKEY']
username = ENV['SPOTIFY_USERNAME']
password = ENV['SPOTIFY_PASSWORD']
track_uri = ARGV[0]
file_path = "spotify.pcm"
recordify = Recordify::Client.new(appkey, nil)
recordify.connect(username, password)
recordify.sink = FileSink.new(file_path)
player = Recordify::Player.new(recordify)


# record track
puts "Writing PCM stream to file #{file_path}"
track = player.play(track_uri)
player.wait
filename = track_uri.split(':')[2]
system "sox -r 44100 -c 2 -t s16 #{file_path} -C 256 #{filename}.mp3"

# set metadata
metadata = recordify.track_metadata(track)
# Load a file
TagLib::FileRef.open("#{filename}.mp3") do |fileref|
  unless fileref.null?
    tag = fileref.tag
    tag.title  = metadata[:name]
    tag.artist  = metadata[:album][:artist][:name]
    tag.album   = metadata[:album][:name]
    tag.year  = metadata[:album][:year]
    tag.track = metadata[:index]
    tag.comment = track_uri
    fileref.save
    #properties = fileref.audio_properties
    #properties.length  = metadata[:duration] / 1000
  end
end
