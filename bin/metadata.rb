#!/usr/bin/env ruby
require_relative '../lib/recordify'
require 'pp'

raise "No spotify track URI given" if ARGV[0].nil?

appkey = ENV['SPOTIFY_APPKEY']
username = ENV['SPOTIFY_USERNAME']
password = ENV['SPOTIFY_PASSWORD']
track_uri = ARGV[0]
recordify = Recordify::Client.new(appkey, nil)
recordify.connect(username, password)

pp recordify.metadata(track_uri)