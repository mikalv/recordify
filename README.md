**NOTE: This is work in progress.**

About
==========================
Sync your spotify library to disk.

Requirements
==========================
* `sox` for PCM -> MP3 conversion
* [gmusicapi](http://unofficial-google-music-api.readthedocs.org/) for google music upload/sync
* [gmusicapi arch linux](https://aur.archlinux.org/packages/python2-gmusicapi)

Usage
==========================

Setup your environment:

```bash
export SPOTIFY_APPKEY=<path to your spotify appkey>
export SPOTIFY_PASSWORD=<your spotify password>
export SPOTIFY_USERNAME=<your spotify username>
```

Sync playlist
--------------------------

```
./bin/sync.rb <spotify playlist uri>
```

Write PCM stream of a track to FIFO
--------------------------
* install sox `brew install sox`

start streaming to **spotify.fifo**

```bash
./bin/play.rb spotify:track:2IORQnCMu5KaiqBmJJPwV4
```

playback from fifo with **sox**

```bash
play -r 44100 -c 2 -t s16 spotify.fifo
```

TODO
==========================
* validate recordings (compare expected length from spotify metadata with actual audio length)
* upload only script. Use environment variable to set oauth token

Timeout / Locked Playback
--------------------------
* check if any error conditions can be used to abort the file sink
* implement retry mechanism
* using Timeout with the track length ?
* ~~watch if record file is not growing ? (trap signal and relaunch sync script)~~


Check Recording Length
-------------------------
* `sox file.mp3 -n stat`
* `mp3info -p "%S" /path/to/file`
* `soxi -s /home/ruben/.recordify/tracks/137UoRpUNnIKwmqNDreh49.mp3`

```
[root@x40 recordify]# soxi -s /home/ruben/.recordify/tracks/137UoRpUNnIKwmqNDreh49.mp3
14108693
[root@x40 recordify]# soxi -d /home/ruben/.recordify/tracks/137UoRpUNnIKwmqNDreh49.mp3
00:05:19.93
[root@x40 recordify]# soxi -D /home/ruben/.recordify/tracks/137UoRpUNnIKwmqNDreh49.mp3
319.925011
```

(Planed) Features
==========================

* sync tracks
* sync playlists
* sync whole library
* convert/compress synced files (MP3 ...)
* sync without interrupting active sessions
* small webfrontend ?
* set bitrate using `sp_session_preferred_bitrate`

Problems
==========================

* ~~audio clicks when streaming (lost frames / buffer size ?)~~
* ~~Trailing loud popping when recording~~
* adjust volume level
* genre not available (use musicbrainz or echonest ?)

Audio Sync Options
==========================

* Music storage
* ~~Google Play Music ? (Only HTML5 Player available in iOS)~~
* Use http://unofficial-google-music-api.readthedocs.org/en/latest/


Resources
==========================


Audio Conversion (using SOX)
--------------------------
http://stefaanlippens.net/audio_conversion_cheat_sheet
http://billposer.org/Linguistics/Computation/SoxTutorial.html


FFI
--------------------------

### **buffer_out** parameters

* https://github.com/Burgestrand/spotify/issues/17
* http://rubydoc.info/github/Burgestrand/Hallon/Hallon/Link#pointer-instance_method
* http://rubydoc.info/github/ffi/ffi/FFI/Buffer
