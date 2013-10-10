require 'spec_helper'
require 'timecop'
require 'bosh/dev/gem_components'

module Bosh::Dev
  describe GemComponents do
    let(:version_file) do
      instance_double('Bosh::Dev::VersionFile', version: '1.5.0.pre.123', write: nil)
    end

    let(:gem_component) do
      instance_double('Bosh::Dev::GemComponent', build_release_gem: nil)
    end

    subject(:gem_components) do
      GemComponents.new('123')
    end

    before do
      GemComponent.stub(:new).and_return(gem_component)
      VersionFile.stub(:new).with(456).and_return(version_file)
      VersionFile.stub(:new).with('123').and_return(version_file)

      Rake::FileUtilsExt.stub(:sh)
    end

    describe '#components' do
      it 'always updates BOSH_VERSION first to ensure it is up-to-date' do
        version_file.should_receive(:write)
        gem_components.components
      end

      it 'returns a list of GemComponent objects for each gem' do
        GemComponent.should_receive(:new).with('agent_client', version_file.version)
        GemComponent.should_receive(:new).with('blobstore_client', version_file.version)
        GemComponent.should_receive(:new).with('bosh-core', version_file.version)
        GemComponent.should_receive(:new).with('bosh-stemcell', version_file.version)
        GemComponent.should_receive(:new).with('bosh_agent', version_file.version)
        GemComponent.should_receive(:new).with('bosh_aws_cpi', version_file.version)
        GemComponent.should_receive(:new).with('bosh_cli', version_file.version)
        GemComponent.should_receive(:new).with('bosh_cli_plugin_aws', version_file.version)
        GemComponent.should_receive(:new).with('bosh_cli_plugin_micro', version_file.version)
        GemComponent.should_receive(:new).with('bosh_common', version_file.version)
        GemComponent.should_receive(:new).with('bosh_cpi', version_file.version)
        GemComponent.should_receive(:new).with('bosh_openstack_cpi', version_file.version)
        GemComponent.should_receive(:new).with('bosh-registry', version_file.version)
        GemComponent.should_receive(:new).with('bosh_vsphere_cpi', version_file.version)
        GemComponent.should_receive(:new).with('director', version_file.version)
        GemComponent.should_receive(:new).with('health_monitor', version_file.version)
        GemComponent.should_receive(:new).with('bosh-release', version_file.version)
        GemComponent.should_receive(:new).with('simple_blobstore_server', version_file.version)

        gem_components.components
      end
    end

    describe '#each' do
      let(:root) { Dir.mktmpdir }
      let(:global_bosh_version_file) { "#{root}/BOSH_VERSION" }

      before do
        stub_const('Bosh::Dev::GemComponent::ROOT', root)
        File.open(global_bosh_version_file, 'w') do |file|
          file.write('123')
        end
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
          bosh_openstack_cpi
          bosh-registry
          bosh_vsphere_cpi
          director
          health_monitor
          bosh-release
          simple_blobstore_server
        ])
      end
    end

    it { should have_db('director') }
    it { should have_db('bosh-registry') }
  end
end
