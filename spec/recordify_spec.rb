require 'spec_helper'
require 'recordify'

describe 'playlist generation' do

  let(:dont_worry_be_jazzy) { 'spotify:user:rj5r:playlist:32wlRCYCpJm2t8UDSuR9MS' }
  let(:do_you_have_soul) { 'spotify:track:2UdqFFp5n4txoqi5mGqrZU'}

  before(:all) do
    appkey = ENV['SPOTIFY_APPKEY']
    @sink = Plaything.new
    @recordify = Recordify::Client.new(appkey, @sink)
    @recordify.connect(ENV['SPOTIFY_USERNAME'], ENV['SPOTIFY_PASSWORD'])
  end

  it 'should load the track' do
    track = @recordify.load_track(do_you_have_soul)
    p @recordify.load_track_metadata(track)
  end

  it 'should load all playlists' do
    playlist = @recordify.playlist(1)
    p @recordify.tracks_for_playlist(playlist)
  end

  it 'should load a playlist' do
    playlist = @recordify.load_playlist(dont_worry_be_jazzy)
    p @recordify.tracks_for_playlist(playlist)
  end

  it 'should play a song' do
    player = Recordify::Player.new(@recordify)
    player.play(do_you_have_soul)
  end
end