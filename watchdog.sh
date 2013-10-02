#!/bin/bash
trap 'killall' INT

INTERVAL=${1:-120}
TMP_FILE="$SPOTIFY_HOME/tmp.pcm"

RETRY_COUNTER=0
RETRY_LIMIT=5

# TODO send notification after X restarts
RESTARTS=0

log() {
   echo "$(date): [retry=$RETRY_COUNTER] $@"
}

killall() {
    log "Shutdown ...."
    kill -TERM 0
    wait
}

start_syncer() {
    ./bin/sync.rb  1>>~/.recordify/debug.log 2>&1 &
    SYNCER_PID=$!
}

restart_syncer() {
    log "Restarting syncer"
    kill -9 $SYNCER_PID
    wait
    start_syncer
    RETRY_COUNTER=0
    ((RESTARTS++))
}

check_start() {
    if [ -n "$SYNCER_PID" ]; then
      log "Started syncer with PID $SYNCER_PID"
    else
      log "Failed to start syncer"
      exit 1
    fi
}

watch_syncer() {
    new_size=`du $SPOTIFY_HOME/tmp.pcm | cut -f 1`
    log "Watching $TMP_FILE (interval $INTERVAL)"

    while true; do
      if [ $RETRY_COUNTER -gt $RETRY_LIMIT ]; then
        restart_syncer
      fi

      sleep $INTERVAL

      if ! [ -f $TMP_FILE ]; then
        log "Waiting for $TMP_FILE to be created."
        ((RETRY_COUNTER++))
        continue
      fi

      old_size=$new_size
      new_size=`du $SPOTIFY_HOME/tmp.pcm | cut -f 1`

      if [ $new_size -gt $old_size ]; then
        log "Probe success: The file is growing $new_size."
        RETRY_COUNTER=0
      else
        log "Probe failure: $TMP_FILE is not growing."
        ((RETRY_COUNTER++))
        continue
       fi
    done
}

start_syncer
check_start
watch_syncer

