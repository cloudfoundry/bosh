#!/bin/bash

set -e
set -u

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

for file in $COPY_KEYS ; do
  file="${file/\%s/$VERSION}"

  echo "$file"

  # occasionally this fails for unexpected reasons; retry a few times
  for i in {1..4}; do
    aws s3 cp "s3://$BUCKET_NAME/$CANDIDATE_PREFIX$file" "s3://$BUCKET_NAME/$PUBLISHED_PREFIX$file" \
      && break \
      || sleep 5
  done

  echo ""
done

echo "Done"
