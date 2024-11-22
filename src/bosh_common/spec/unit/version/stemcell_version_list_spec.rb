require 'spec_helper'

module Bosh::Common::Version
  describe StemcellVersionList do
    let(:version_list) { described_class.parse(versions) }

    describe '#parse' do
      let(:versions) { ['1.0.1', '10.9-dev', '1471.2'] }

      it 'creates a new object' do
        expect(described_class.parse(versions)).to be_instance_of(described_class)
      end

      it 'delegates to VersionList' do
        expect(VersionList).to receive(:parse).with(versions, StemcellVersion).and_call_original

        described_class.parse(versions)
      end
    end

    describe 'equals' do
      let(:versions) { ['1.0.0', '1.0.1', '1471.2'] }

      it 'supports equality comparison' do
        expect(version_list).to eq(StemcellVersionList.parse(versions))
      end

      it 'supports equality comparison with VersionList' do
        expect(version_list).to eq(VersionList.parse(versions, StemcellVersion))
      end
    end
  end
end
