require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure_name) { 'vsphere' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }

    let(:gems_generator) { instance_double('Bosh::Dev::GemsGenerator', build_gems_into_release_dir: nil) }

    let(:stemcell_environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      build_path: '/fake/build_path',
                      work_path: '/fake/work_path',
                      sanitize: nil)
    end
    let(:stemcell_builder_options) do
      instance_double('Bosh::Dev::StemcellBuilderOptions')
    end
    let(:stemcell_rake_methods) { instance_double('Bosh::Dev::StemcellRakeMethods', build_stemcell: nil) }
    let(:args) do
      {
        tarball: 'fake release path',
        infrastructure: 'vsphere',
        stemcell_version: build_number,
        stemcell_tgz: 'bosh-stemcell-869-vsphere-esxi-ubuntu.tgz',
      }
    end

    subject(:builder) do
      StemcellBuilder.new(infrastructure_name, build)
    end

    before do
      GemsGenerator.stub(:new).and_return(gems_generator)
      StemcellEnvironment.stub(:new).with(infrastructure_name: infrastructure_name).and_return(stemcell_environment)
      StemcellBuilderOptions.stub(:new).with(args: args).and_return(stemcell_builder_options)
    end

    describe '#build' do
      before do
        StemcellRakeMethods.stub(:new).with(stemcell_environment: stemcell_environment,
                                            stemcell_builder_options: stemcell_builder_options).and_return(stemcell_rake_methods)

        stemcell_rake_methods.stub(:build_stemcell) do
          FileUtils.mkdir_p('/fake/work_path/work')
          FileUtils.touch('/fake/work_path/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end
      end

      it 'sanitizes the stemcell environment' do
        stemcell_environment.should_receive(:sanitize)

        builder.build
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
