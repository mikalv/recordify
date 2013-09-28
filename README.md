**NOTE: This is a work in progress**

About
==========================
Library to sync your spotify library to disk.

Usage
==========================


Write stream to FIFO
--------------------------
* install sox `brew install sox`

start streaming to **spotify.fifo**

```bash
export SPOTIFY_APPKEY=<path to your spotify appkey>
export SPOTIFY_PASSWORD=< your spotify password>
export SPOTIFY_USERNAME=<your spotify username>
ruby bin/play.rb spotify:track:2IORQnCMu5KaiqBmJJPwV4
```

playback from fifo with **sox**

```bash
play -r 44100 -c 2 -t s16 spotify.fifo
```

(Planed) Features
==========================
* sync single tracks
* convert/compress synced files (MP3 ...)
* sync whole playlists / whole library
* sync without interrupting active sessions

Resources
==========================

FFI
--------------------------

### **buffer_out** parameters

* https://github.com/Burgestrand/spotify/issues/17
* http://rubydoc.info/github/Burgestrand/Hallon/Hallon/Link#pointer-instance_method
* http://rubydoc.info/github/ffi/ffi/FFI/Buffer
