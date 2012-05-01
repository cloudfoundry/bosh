#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ -z "${bosh_agent_src_dir:-}" ]
then
  # Use relative path to the BOSH agent
  bosh_agent_src_dir=$(readlink -nf $base_dir/../../..)
fi

ruby="ruby -I$bosh_agent_src_dir/lib"
bosh_agent_src_version=$($ruby -r"agent/version" -e"puts Bosh::Agent::VERSION")

persist_dir bosh_agent_src_dir
persist_value bosh_agent_src_version

assert_value bosh_agent_infrastructure_name
export bosh_agent_infrastructure_name

# Translate templates
ruby -rerb <<EOS
env = Hash[ENV]
env.default_proc = lambda { |h, k| raise "#{k} is not defined" }
Dir["${assets_dir}/**/*.erb"].each do |tpl|
  without_ext = tpl[0..-5]
  File.open(without_ext, "w") do |f|
    f.write(ERB.new(File.read(tpl)).result(binding))
  end
end
EOS
