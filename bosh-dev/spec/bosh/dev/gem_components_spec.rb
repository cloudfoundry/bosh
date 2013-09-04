require 'spec_helper'
require 'timecop'
require 'bosh/dev/gem_components'

module Bosh::Dev
  describe GemComponents do
    subject(:gem_components) do
      GemComponents.new
    end

    its(:to_a) do
      should eq(%w[
        agent_client
        blobstore_client
        bosh-core
        bosh-stemcell
        bosh_agent
        bosh_aws_cpi
        bosh_cli
        bosh_cli_plugin_aws
        bosh_cli_plugin_micro
        bosh_common
        bosh_cpi
        bosh_encryption
        bosh_openstack_cpi
        bosh_registry
        bosh_vsphere_cpi
        director
        health_monitor
        monit_api
        package_compiler
        ruby_vim_sdk
        simple_blobstore_server
      ])
    end

    it { should have_db('director') }
    it { should have_db('bosh_registry') }
  end
end
