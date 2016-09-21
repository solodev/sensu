#!/bin/bash

OUTPUT="$(duply $@)"
STATUS=$?

echo "{\"name\": \"cron_duply_backups\", \"output\": \"$OUTPUT\", \"status\": $STATUS}" | nc localhost 3030

echo $OUTPUT
exit $STATUS
