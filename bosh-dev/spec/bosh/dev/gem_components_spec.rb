require 'spec_helper'
require 'timecop'
require 'bosh/dev/gem_components'

module Bosh::Dev
  describe GemComponents do
    let(:gem_version) do
      instance_double('Bosh::Dev::GemVersion', version: '1.5.0.pre.123')
    end

    let(:gem_component) do
      instance_double('Bosh::Dev::GemComponent', build_release_gem: nil)
    end

    subject(:gem_components) do
      GemComponents.new('123')
    end

    before do
      GemComponent.stub(:new).and_return(gem_component)
      GemVersion.stub(:new).with(456).and_return(gem_version)
      GemVersion.stub(:new).with('123').and_return(gem_version)

      Rake::FileUtilsExt.stub(:sh)
    end

    describe '#components' do
      it 'returns a list of GemComponent objects for each gem' do
        GemComponent.should_receive(:new).with('agent_client', gem_version.version)
        GemComponent.should_receive(:new).with('blobstore_client', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-core', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-stemcell', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_agent', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_aws_cpi', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_cli', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_cli_plugin_aws', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_cli_plugin_micro', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_common', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_cpi', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_openstack_cpi', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-registry', gem_version.version)
        GemComponent.should_receive(:new).with('bosh_vsphere_cpi', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-director', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-director-core', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-monitor', gem_version.version)
        GemComponent.should_receive(:new).with('bosh-release', gem_version.version)
        GemComponent.should_receive(:new).with('simple_blobstore_server', gem_version.version)

        gem_components.components
      end
    end

    describe '#each' do
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
          bosh_openstack_cpi
          bosh-registry
          bosh_vsphere_cpi
          bosh-director
          bosh-director-core
          bosh-monitor
          bosh-release
          simple_blobstore_server
        ])
      end
    end

    it { should have_db('bosh-director') }
    it { should have_db('bosh-registry') }
  end
end
