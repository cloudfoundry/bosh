require 'spec_helper'
require 'bosh/dev/vsphere_cpi_release_components'

module Bosh::Dev
  describe VsphereCpiReleaseComponents do
    subject(:vsphere_cpi_release_components) do
      VsphereCpiReleaseComponents.new
    end

    let(:bosh_common_gem_component) { instance_double('Bosh::Dev::GemComponent', dependencies: []) }
    let(:bosh_cpi_gem_component) { instance_double('Bosh::Dev::GemComponent', dependencies: []) }
    let(:bosh_vsphere_cpi_gem_component) { instance_double('Bosh::Dev::GemComponent', dependencies: []) }

    before do
      allow(Bosh::Dev::GemComponent).to receive(:new).with('bosh_common', anything).and_return(bosh_common_gem_component)
      allow(Bosh::Dev::GemComponent).to receive(:new).with('bosh_cpi', anything).and_return(bosh_cpi_gem_component)
      allow(Bosh::Dev::GemComponent).to receive(:new).with('bosh_vsphere_cpi', anything).and_return(bosh_vsphere_cpi_gem_component)
    end

    describe '#build_release_gems' do
      before { allow(Rake::FileUtilsExt).to receive(:sh) }
      let(:dependency) { double('fake-dependency', name: 'fake-dependency-name', version: '0.0.1') }

      it 'builds component gems' do
        expect(bosh_common_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})
        expect(bosh_cpi_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})
        expect(bosh_vsphere_cpi_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})

        vsphere_cpi_release_components.build_release_gems
      end

      it 'copies vendored dependencies' do
        allow(bosh_common_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})
        allow(bosh_cpi_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})
        allow(bosh_vsphere_cpi_gem_component).to receive(:build_gem).with(%r{/tmp/all_the_gems/\d+})

        allow(bosh_common_gem_component).to receive(:dependencies).and_return([dependency])

        expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp .*vendor/cache/fake-dependency-name-0.0.1.gem .})

        vsphere_cpi_release_components.build_release_gems
      end
    end
  end
end
