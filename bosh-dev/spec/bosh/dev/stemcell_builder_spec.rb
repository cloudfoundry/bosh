require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure) { 'vsphere' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }
    let(:environment) { instance_double('Bosh::Dev::StemcellEnvironment', sanitize: nil) }
    let(:stemcell_rake_methods) { instance_double('Bosh::Dev::StemcellRakeMethods', build_stemcell: nil) }

    subject(:builder) do
      StemcellBuilder.new(infrastructure, build)
    end

    before do
      StemcellEnvironment.stub(:new).with(builder).and_return(environment)
    end

    describe '#build' do
      before do
        StemcellRakeMethods.stub(:new).with(args: {
          tarball: 'fake release path',
          infrastructure: 'vsphere',
          stemcell_version: build_number,
          stemcell_tgz: 'bosh-stemcell-869-vsphere-esxi-ubuntu.tgz',
        }).and_return(stemcell_rake_methods)

        stemcell_rake_methods.stub(:build_stemcell) do
          FileUtils.mkdir_p('/mnt/stemcells/vsphere/work/work')
          FileUtils.touch('/mnt/stemcells/vsphere/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end
      end

      it 'sanitizes the stemcell environment' do
        environment.should_receive(:sanitize)
        builder.build
      end

      it 'sets BUILD_PATH, WORK_PATH as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere/work')

        builder.build
      end

      it 'creates a basic stemcell and returns its absolute path' do
        expect(builder.build).to eq('/mnt/stemcells/vsphere/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
      end

      it 'creates a basic stemcell' do
        expect {
          builder.build
        }.to change { File.exist?('/mnt/stemcells/vsphere/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') }.to(true)
      end

      context 'when the micro stemcell is not created' do
        before do
          stemcell_rake_methods.stub(:build_stemcell)
        end

        it 'fails early and loud' do
          expect {
            builder.build
          }.to raise_error(/\/bosh-stemcell-869-vsphere-esxi-ubuntu\.tgz does not exist/)
        end
      end
    end
  end
end
