#!/bin/bash

fly -t production \
set-pipeline -p bosh:os-image:3363.x \
-c ci/pipelines/os-images/pipeline.yml \
--load-vars-from <(lpass show -G "concourse:production pipeline:os-images" --id 3790608950700570527 --notes)
