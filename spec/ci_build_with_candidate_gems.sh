#!/bin/bash -l
set -e

script_dir=`dirname $0`

echo "source 'https://s3.amazonaws.com/bosh-ci-pipeline/gems/'" > gemfile_tmp

sed "s/:path.*$/\"~>1.5.0.pre3\"/g" Gemfile >> gemfile_tmp

mv gemfile_tmp Gemfile

$script_dir/ci_build.sh $@