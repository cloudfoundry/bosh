#!/bin/bash
find /var/vcap/store/director/tasks -mtime +1 -a -not -name "*.gz" -a -type f -exec gzip '{}' \;
