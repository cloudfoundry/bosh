require 'spec_helper'
require 'timecop'
require 'bosh/dev/gem_components'

module Bosh::Dev
  describe GemComponents do
    let(:gem_version) do
      instance_double('Bosh::Dev::GemVersion', version: '1.5.0.pre.123')
    end

    let(:gem_component) do
      instance_double('Bosh::Dev::GemComponent', build_gem: nil)
    end

    let(:expected_gems) do
      %w(
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
        bosh_warden_cpi
        bosh-director
        bosh-director-core
        bosh-monitor
        bosh-release
        simple_blobstore_server
      )
    end

    let(:expected_components) do
      expected_gems.map do |gem|
        instance_double('Bosh::Dev::GemComponent', build_gem: nil, name: gem,
          dependencies: [], update_version: nil)
      end
    end

    subject(:gem_components) do
      GemComponents.new('123')
    end

    before do
      expected_components.each do |component|
        allow(GemComponent).to receive(:new).with(component.name, anything).and_return(component)
      end

      allow(GemVersion).to receive(:new).with(456).and_return(gem_version)
      allow(GemVersion).to receive(:new).with('123').and_return(gem_version)

      allow(Rake::FileUtilsExt).to receive(:sh)
    end

    describe '#components' do
      it 'returns a list of GemComponent objects for each gem' do
        expected_gems.each do |gem|
          expect(GemComponent).to receive(:new).with(gem, gem_version.version)
        end

        gem_components.components
      end
    end

    describe '#each' do
      its(:to_a) do
        should eq(expected_gems)
      end
    end

    it { should have_db('bosh-director') }
    it { should have_db('bosh-registry') }

    describe '#build_release_gems' do
      it 'updates components versions' do
        expected_components.each do |component|
          expect(component).to receive(:update_version)
        end

        gem_components.build_release_gems
      end

      it 'builds components gems' do
        expected_components.each do |component|
          expect(component).to receive(:build_gem).with(/pkg\/gems/)
        end

        gem_components.build_release_gems
      end

      it 'copies vendored gems' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp .*/pkg/gems/\*\.gem /tmp/all_the_gems/\d+})
        expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp .*/vendor/cache/\*\.gem /tmp/all_the_gems/\d+})

        gem_components.build_release_gems
      end

      context 'when components have dependencies' do
        let(:fake_dependency) { double(:fake_dependency, name: 'fake-dep-name') }

        it 'copies vendored dependencies' do
          allow(expected_components[0]).to receive(:dependencies).and_return([fake_dependency])

          expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp /tmp/all_the_gems/\d+/fake-dep-name-\*\.gem \.})

          gem_components.build_release_gems
        end
      end

      context 'when components have database dependency' do
        let(:fake_dependency) { double(:fake_dependency, name: 'fake-dep-name') }

        it 'copies pg and mysql gems' do
          # Only bosh-director and bosh-registry will copy db gems
          allow(expected_components[0]).to receive(:name).and_return('bosh-director')
          allow(expected_components[0]).to receive(:dependencies).and_return([fake_dependency])

          allow(expected_components[1]).to receive(:name).and_return('bosh-registry')
          allow(expected_components[1]).to receive(:dependencies).and_return([fake_dependency])

          expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp /tmp/all_the_gems/\d+/pg\*\.gem \.}).twice
          expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp /tmp/all_the_gems/\d+/mysql\*\.gem \.}).twice

          gem_components.build_release_gems
        end
      end
    end
  end
end
