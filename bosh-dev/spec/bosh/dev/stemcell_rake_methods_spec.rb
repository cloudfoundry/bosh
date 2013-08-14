require 'spec_helper'
require 'bosh/dev/stemcell_rake_methods'

module Bosh::Dev
  describe StemcellRakeMethods do
    let(:env) { { 'FAKE' => 'ENV' } }
    let(:infrastructure) { 'aws' }
    let(:stemcell_tgz) { 'fake-stemcell-filename.tgz' }
    let(:spec) { 'stemcell-aws' }
    let(:source_root) { File.expand_path('../../../../..', __FILE__) }

    let(:build_from_spec) do
      instance_double('Bosh::Dev::BuildFromSpec', build: nil)
    end

    let(:stemcell_builder_options) do
      instance_double('Bosh::Dev::StemcellBuilderOptions',
                      basic: { basic: 'options' },
                      micro: { micro: 'options' })
    end

    let(:args) do
      {
        infrastructure: infrastructure,
        stemcell_tgz: stemcell_tgz,
        stemcell_version: '123'
      }
    end

    subject(:stemcell_rake_methods) do
      StemcellRakeMethods.new(args: args, environment: env)
    end

    before do
      Bosh::Dev::StemcellBuilderOptions.stub(:new).with(args: args, environment: env).and_return(stemcell_builder_options)
    end

    describe '#build_basic_stemcell' do
      let(:gems_generator) { instance_double('Bosh::Dev::GemsGenerator', build_gems_into_release_dir: nil) }

      before do
        Bosh::Dev::BuildFromSpec.stub(:new).with(env, spec, { basic: 'options' }).and_return(build_from_spec)
        Bosh::Dev::GemsGenerator.stub(:new).and_return(gems_generator)
      end

      it "builds bosh's gems so we have the gem for the agent" do
        gems_generator.should_receive(:build_gems_into_release_dir)

        stemcell_rake_methods.build_basic_stemcell
      end

      it 'builds a basic stemcell with the appropriate name and options' do
        build_from_spec.should_receive(:build)

        stemcell_rake_methods.build_basic_stemcell
      end
    end

    describe '#build_micro_stemcell' do
      let(:gems_generator) { instance_double('Bosh::Dev::GemsGenerator', build_gems_into_release_dir: nil) }

      before do
        Bosh::Dev::GemsGenerator.stub(:new).and_return(gems_generator)
        Bosh::Dev::BuildFromSpec.stub(:new).with(env, spec, { micro: 'options' }).and_return(build_from_spec)
      end

      context 'when a release tarball is provided' do
        before do
          args.merge!(tarball: 'fake/release.tgz')
        end

        it "builds bosh's gems so we have the gem for the agent" do
          gems_generator.should_receive(:build_gems_into_release_dir)

          stemcell_rake_methods.build_micro_stemcell
        end

        it 'builds a micro stemcell with the appropriate name and options' do
          build_from_spec.should_receive(:build)

          stemcell_rake_methods.build_micro_stemcell
        end
      end
    end
  end
end
