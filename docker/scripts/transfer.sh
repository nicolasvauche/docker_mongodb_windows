#!/bin/sh
set -eu
action="$1"
archive="$2"
case "$action" in
  backup)
    exec mongodump --host 127.0.0.1 --port 27017 \
      --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" \
      --authenticationDatabase admin --db "$MONGO_INITDB_DATABASE" --gzip --archive="$archive"
    ;;
  restore)
    exec mongorestore --host 127.0.0.1 --port 27017 \
      --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" \
      --authenticationDatabase admin --gzip --archive="$archive" --stopOnError \
      --nsInclude "$3.*" --nsFrom "$3.*" --nsTo "$4.*"
    ;;
  *) echo 'Action inconnue' >&2; exit 1 ;;
esac
