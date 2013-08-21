require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure_name) { 'vsphere' }

    let(:stemcell_environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      build_path: '/fake/build_path',
                      work_path: '/fake/work_path')
    end
    let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Vsphere', name: 'vsphere') }
    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }

    let(:gems_generator) { instance_double('Bosh::Dev::GemsGenerator', build_gems_into_release_dir: nil) }

    let(:stemcell_builder_options) { instance_double('Bosh::Dev::StemcellBuilderOptions') }
    let(:stemcell_builder_command) { instance_double('Bosh::Dev::BuildFromSpec', build: nil) }

    let(:args) do
      {
        tarball: 'fake release path',
        infrastructure: infrastructure,
        stemcell_version: build_number
      }
    end
    let(:stemcell_file_path) { '/fake/work_path/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz' }

    subject(:builder) do
      StemcellBuilder.new(infrastructure_name, build)
    end

    describe '#build' do
      before do
        Bosh::Stemcell::Infrastructure.stub(:for).with('vsphere').and_return(infrastructure)
        GemsGenerator.stub(:new).and_return(gems_generator)
        StemcellEnvironment.stub(:new).with(infrastructure_name: infrastructure.name).and_return(stemcell_environment)
        StemcellBuilderOptions.stub(:new).with(args: args).and_return(stemcell_builder_options)
        StemcellBuilderCommand.stub(:new).with(stemcell_environment,
                                               stemcell_builder_options).and_return(stemcell_builder_command)

        stemcell_builder_command.stub(:build) do
          FileUtils.mkdir_p('/fake/work_path/work')
          FileUtils.touch(stemcell_file_path)
          stemcell_file_path
        end
      end

      it 'generates the bosh gems' do
        gems_generator.should_receive(:build_gems_into_release_dir)

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
          stemcell_builder_command.stub(build: stemcell_file_path)
        end

        it 'fails early and loud' do
          expect {
            builder.build
          }.to raise_error("#{stemcell_file_path} does not exist")
        end
      end
    end
  end
end
