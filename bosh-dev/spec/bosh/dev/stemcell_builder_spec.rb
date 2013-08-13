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
    let(:stemcell_rake_methods) { instance_double('Bosh::Dev::StemcellRakeMethods', build_basic_stemcell: nil, build_micro_stemcell: nil) }

    subject(:builder) do
      StemcellBuilder.new(stemcell_type, infrastructure, build)
    end

    before do
      StemcellEnvironment.stub(:new).with(builder).and_return(environment)
    end

    describe '#build' do
      context 'when building a micro stemcell' do
        let(:stemcell_type) { 'micro' }

        before do
          StemcellRakeMethods.stub(:new).with(args: {
            tarball: 'fake release path',
            infrastructure: 'vsphere',
            version: build_number,
            stemcell_tgz: 'micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz',
          }).and_return(stemcell_rake_methods)

          stemcell_rake_methods.stub(:build_micro_stemcell) do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-micro/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-micro/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-micro/work')

          builder.build
        end

        it 'creates a micro stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end

        it 'creates a micro stemcell' do
          expect { builder.build }.to change { File.exist?('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') }.to(true)
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_rake_methods.stub(:build_micro_stemcell)
          end

          it 'fails early and loud' do
            expect {
              builder.build
            }.to raise_error(/micro-bosh-stemcell-869-vsphere-esxi-ubuntu\.tgz does not exist/)
          end
        end
      end

      context 'when building a basic stemcell' do
        let(:stemcell_type) { 'basic' }

        before do
          StemcellRakeMethods.stub(:new).with(args: {
            infrastructure: 'vsphere',
            version: build_number,
            stemcell_tgz: 'bosh-stemcell-869-vsphere-esxi-ubuntu.tgz',
          }).and_return(stemcell_rake_methods)

          stemcell_rake_methods.stub(:build_basic_stemcell) do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-basic/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-basic/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-basic/work')

          builder.build
        end

        it 'creates a basic stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end

        it 'creates a basic stemcell' do
          expect {
            builder.build
          }.to change { File.exist?('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') }.to(true)
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_rake_methods.stub(:build_basic_stemcell)
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
end
