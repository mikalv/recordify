#!/usr/bin/env python2
# see http://unofficial-google-music-api.readthedocs.org/en/latest/usage.html#usage
# arch linux 'pacman -S python2-pip && pip2 install gmusicapi'

from gmusicapi import Musicmanager
from gmusicapi.compat import my_appdirs
import sys
import os.path

mm = Musicmanager()

# TODO use generic path for credentials
OAUTH_FILEPATH = os.path.join(my_appdirs.user_data_dir, 'oauth.cred')
if not os.path.isfile(OAUTH_FILEPATH):
    mm.perform_oauth()

mm.login()
# TODO handle errors (existing tracks/duplicates ...)
print('upload started')
mm.upload(sys.argv[1])
