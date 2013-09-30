#!/usr/bin/env python
# see http://unofficial-google-music-api.readthedocs.org/en/latest/usage.html#usage

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
mm.upload(sys.argv[1])
print 'finished upload'
sys.exit(0)

