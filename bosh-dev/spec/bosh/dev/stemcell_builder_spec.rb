require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure_name) { 'vsphere' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }
    let(:stemcell_environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      build_path: '/fake/build_path',
                      work_path: '/fake/work_path',
                      sanitize: nil)
    end
    let(:stemcell_rake_methods) { instance_double('Bosh::Dev::StemcellRakeMethods', build_stemcell: nil) }

    subject(:builder) do
      StemcellBuilder.new(infrastructure_name, build)
    end

    before do
      StemcellEnvironment.stub(:new).with(infrastructure_name: infrastructure_name).and_return(stemcell_environment)
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
          FileUtils.mkdir_p('/fake/work_path/work')
          FileUtils.touch('/fake/work_path/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end
      end

      it 'sanitizes the stemcell environment' do
        stemcell_environment.should_receive(:sanitize)
        builder.build
      end

      it 'sets BUILD_PATH, WORK_PATH as expected' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/fake/build_path')
        ENV.should_receive(:[]=).with('WORK_PATH', '/fake/work_path')

        builder.build
      end

      it 'creates a basic stemcell and returns its absolute path' do
        expect(builder.build).to eq('/fake/work_path/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
      end

      it 'creates a basic stemcell' do
        expect {
          builder.build
        }.to change { File.exist?('/fake/work_path/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') }.to(true)
      end

      context 'when the stemcell is not created' do
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
