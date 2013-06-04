require 'spec_helper'
require_relative '../../lib/helpers/candidate_artifacts'

module Bosh
  module Helpers
    describe CandidateArtifacts do
      let(:ami_id) do
        'fake-ami-id'
      end

      let(:ami) do
        double(Ami, publish: ami_id).as_null_object
      end

      let(:light_stemcell) do
        double(LightStemcell).as_null_object
      end

      subject(:candidate_artifacts) { described_class.new('fake-stemcell.tgz') }

      before do
        Ami.stub(:new).with('fake-stemcell.tgz').and_return(ami)
        LightStemcell.stub(:new).with(ami).and_return(light_stemcell)
      end

      it 'creates an ami from a stemcell' do
        ami.should_receive(:publish).and_return(ami_id)

        candidate_artifacts.publish
      end

      it 'publishes a light stemcell for the new ami and provided stemcell' do
        light_stemcell.should_receive(:publish).with(ami_id)

        candidate_artifacts.publish
      end
    end
  end
end
