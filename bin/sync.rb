#!/usr/bin/env ruby
require_relative '../lib/recordify'

syncer = Recordify::Syncer.new
#syncer.recordify.debug!
syncer.start
playlist_uri = ARGV[0]
if playlist_uri
  syncer.sync(playlist_uri)
else
  syncer.sync_all
end
