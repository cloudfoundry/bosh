require 'spec_helper'
require 'timecop'
require 'bosh/dev/gem_components'

module Bosh::Dev
  describe GemComponents do
    subject(:gem_components) do
      GemComponents.new
    end

    describe '#dot_gems' do
      let(:root) { Dir.mktmpdir }
      let(:global_bosh_version_file) { "#{root}/BOSH_VERSION" }

      before do
        stub_const('Bosh::Dev::GemComponent::ROOT', root)
        File.open(global_bosh_version_file, 'w') do |file|
          file.write('123')
        end
      end

      its(:dot_gems) do
        should eq(%w[
          agent_client-123.gem
          blobstore_client-123.gem
          bosh-core-123.gem
          bosh-stemcell-123.gem
          bosh_agent-123.gem
          bosh_aws_cpi-123.gem
          bosh_cli-123.gem
          bosh_cli_plugin_aws-123.gem
          bosh_cli_plugin_micro-123.gem
          bosh_common-123.gem
          bosh_cpi-123.gem
          bosh_encryption-123.gem
          bosh_openstack_cpi-123.gem
          bosh_registry-123.gem
          bosh_vsphere_cpi-123.gem
          director-123.gem
          health_monitor-123.gem
          bosh-release-123.gem
          simple_blobstore_server-123.gem
        ])
      end
    end

    it { should have_db('director') }
    it { should have_db('bosh_registry') }
  end
end
