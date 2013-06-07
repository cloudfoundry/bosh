require 'spec_helper'
require_relative '../../lib/helpers/candidate_artifacts'

module Bosh
  module Helpers
    describe CandidateArtifacts do
      let(:light_stemcell) do
        double(Stemcell, path: light_stemcell_path)
      end

      let(:light_stemcell_path) { 'light-fake-stemcell.tgz' }

      let(:stemcell) do
        double(Stemcell, path: stemcell_path, infrastructure: 'aws', name: 'bosh-stemcell')
      end

      let(:stemcell_path) { 'fake-stemcell.tgz' }

      subject(:candidate_artifacts) { described_class.new(stemcell_path) }

      before do
        Pipeline.any_instance.stub(:publish)
        Stemcell.stub(:new).with(stemcell_path).and_return(stemcell)
      end


      it 'publishes the light stemcell to the pipeline' do
        stemcell.should_receive(:create_light_stemcell).and_return(light_stemcell)
        Pipeline.any_instance.should_receive(:publish).with(light_stemcell)

        candidate_artifacts.publish
      end
    end
  end
end
