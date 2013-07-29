#!/bin/sh

# All-in-one bosh with Micro + Warden CPI

spec/ci_build_stemcell.sh micro warden
tar xvfz foo.tgz
ovftool image.ovf warden

# Start VM

# Boostrap VM

# SSH into VM



# Install Warden CPI

# cd bosh_warden_cpi
# gem build bosh_warden_cpi.gemspec
# gem install bosh_warden_cpi_*.gem
# cd -

# Install Warden

git clone git@github.com:cloudfoundry/warden.git
cd warden/warden
bundle
bundle exec rake setup[config/linux.yml]
bundle exec rake warden:start[config/linux.yml]
cd -

# Reconfigure director (Refer to config/warden.yml)

# Restart director

monit restart all

# Bosh

run_bosh create release --force
run_bosh target $DIRECTOR
run_bosh login $BOSH_USER $BOSH_PASSWORD

OUTPUT=/tmp/bosh_output
run_bosh upload release --rebase 2>&1 | tee $OUTPUT; test ${PIPESTATUS[0]} -eq 0 || grep "without any job or package changes" $OUTPUT

run_bosh deployment warden_cpi.yml
# run_bosh diff ${WORKSPACE}/deployments-aws/staging/cf-staging-template.yml.erb