require 'spec_helper'
require 'bosh/dev/vsphere_cpi_release_components'

module Bosh::Dev
  describe VsphereCpiReleaseComponents do
    subject(:vsphere_cpi_release_components) do
      VsphereCpiReleaseComponents.new
    end

    describe '#build_gems' do
      before { allow(Rake::FileUtilsExt).to receive(:sh) }
      let(:dependency) { double('fake-dependency', name: 'fake-dependency-name', version: '0.0.1') }
      before do
        allow(Bundler::Resolver).to receive(:resolve).and_return([dependency])
      end

      it 'builds component gems' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(/gem build bosh_common.gemspec/)
        expect(Rake::FileUtilsExt).to receive(:sh).with(/gem build bosh_cpi.gemspec/)
        expect(Rake::FileUtilsExt).to receive(:sh).with(/gem build bosh_vsphere_cpi.gemspec/)

        vsphere_cpi_release_components.build_gems
      end

      it 'copies vendored dependencies' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(%r{cp .*vendor/cache/fake-dependency-name-0.0.1.gem .})

        vsphere_cpi_release_components.build_gems
      end
    end
  end
end
