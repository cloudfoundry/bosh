require 'spec_helper'
require 'cloud/aws/stemcell_finder'

module Bosh::AwsCloud
  describe StemcellFinder do
    describe '.find_by_region_and_id' do
      context 'when id ends with " light"' do
        let(:region) { double('aws region') }
        let(:stemcell) { double('heavy stemcell') }
        before { allow(Stemcell).to receive(:find).with(region, 'ami-id').and_return(stemcell) }

        it 'constructs a light stemcell with a heavy stemcell' do
          light_stemcell = double('light stemcell')
          expect(LightStemcell).to receive(:new).with(stemcell, anything).and_return(light_stemcell)

          expect(described_class.find_by_region_and_id(region, 'ami-id light')).to eq(light_stemcell)
        end

        it 'gets the BOSH logger and injects it to the LightStemcell' do
          logger = double('logger')
          allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)

          expect(LightStemcell).to receive(:new).with(stemcell, logger)
          described_class.find_by_region_and_id(region, 'ami-id light')
        end
      end

      context 'when id does not end with " light"' do
        it 'constructs a heavy stemcell' do
          stemcell = double('heavy stemcell')
          region = double('aws region')

          expect(Stemcell).to receive(:find).with(region, 'ami-id').and_return(stemcell)

          expect(described_class.find_by_region_and_id(region, 'ami-id')).to eq(stemcell)
        end
      end
    end
  end
end
