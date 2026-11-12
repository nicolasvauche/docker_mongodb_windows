#!/bin/sh
set -eu
# Do not mark the temporary initialization server as ready.
test "$(cat /proc/1/comm)" = mongod
exec mongosh --quiet --nodb --file /opt/mongodb-tools/connect.js --file /opt/mongodb-tools/check.js
