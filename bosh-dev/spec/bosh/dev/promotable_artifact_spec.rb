require 'spec_helper'

module Bosh::Dev
  describe PromotableArtifact do
    describe '#promote' do
      subject(:promotable_artifact) do
        PromotableArtifact.new('some-command that-promotes')
      end

      it 'simply shells out with the provided command' do
        Rake::FileUtilsExt.should_receive(:sh).with('some-command that-promotes')

        promotable_artifact.promote
      end
    end
  end
end
