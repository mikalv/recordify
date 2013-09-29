**NOTE: This is work in progress.**

About
==========================
Sync your spotify library to disk.

Usage
==========================

Write PCM stream of a track to FIFO
--------------------------
* install sox `brew install sox`

start streaming to **spotify.fifo**

```bash
export SPOTIFY_APPKEY=<path to your spotify appkey>
export SPOTIFY_PASSWORD=<your spotify password>
export SPOTIFY_USERNAME=<your spotify username>
./bin/play.rb spotify:track:2IORQnCMu5KaiqBmJJPwV4
```

playback from fifo with **sox**

```bash
play -r 44100 -c 2 -t s16 spotify.fifo
```

(Planed) Features
==========================
* sync tracks
* sync playlists
* sync whole library
* convert/compress synced files (MP3 ...)
* sync without interrupting active sessions

Resources
==========================

FFI
--------------------------

### **buffer_out** parameters

* https://github.com/Burgestrand/spotify/issues/17
* http://rubydoc.info/github/Burgestrand/Hallon/Hallon/Link#pointer-instance_method
* http://rubydoc.info/github/ffi/ffi/FFI/Buffer
