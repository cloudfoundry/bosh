require 'spec_helper'
require 'bosh/stemcell/stemcell_builder'
require 'bosh/dev/gem_components'
require 'bosh/stemcell/build_environment'
require 'bosh/stemcell/stage_collection'
require 'bosh/stemcell/stage_runner'

describe Bosh::Stemcell::StemcellBuilder do
  subject(:builder) do
    described_class.new(
      gem_components: gem_components,
      environment: environment,
      collection: collection,
      runner: runner,
    )
  end

  let(:gem_components) { instance_double('Bosh::Dev::GemComponents', build_release_gems: nil) }
  let(:environment) { instance_double('Bosh::Stemcell::BuildEnvironment', prepare_build: nil) }
  let(:collection) do
    instance_double(
      'Bosh::Stemcell::StageCollection',
      extract_operating_system_stages: [],
      infrastructure_stages: [],
      agent_stages: [],
    )
  end
  let(:runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }

  describe '#build' do
    it 'builds the gem components' do
      expect(gem_components).to receive(:build_release_gems)
      builder.build
    end

    it 'prepares the build environment' do
      expect(environment).to receive(:prepare_build)
      builder.build
    end

    it 'runs the extract OS, agent, and infrastructure stages' do
      allow(collection).to receive(:extract_operating_system_stages).and_return([:extract_stage])
      allow(collection).to receive(:agent_stages).and_return([:agent_stage])
      allow(collection).to receive(:infrastructure_stages).and_return([:infrastructure_stage])
      expect(runner).to receive(:configure_and_apply).with([:extract_stage, :agent_stage, :infrastructure_stage])

      builder.build
    end
  end
end
