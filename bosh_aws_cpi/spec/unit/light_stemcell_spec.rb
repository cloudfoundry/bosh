require 'cloud/aws/light_stemcell'

module Bosh::AwsCloud
  describe LightStemcell do
    let(:heavy_stemcell) { double('heavy stemcell', id: 'fake-ami-id') }
    let(:logger) { double('logger') }
    subject(:light_stemcell) { described_class.new(heavy_stemcell, logger) }

    describe '#delete' do
      it 'does not delete the light stemcell' do
        allow(logger).to receive(:info)
        expect(heavy_stemcell).not_to receive(:delete)
        light_stemcell.delete
      end

      it 'logs at INFO about the deletion' do
        expect(logger).to receive(:info).with("NoOP: Deleting light stemcell 'fake-ami-id'")
        light_stemcell.delete
      end
    end

    describe '#id' do
      it 'appends " light" to the id of heavy stemcell to distinguish the light stemcell from a heavy one' do
        expect(heavy_stemcell).to receive(:id).and_return('ami-id')
        expect(light_stemcell.id).to eq('ami-id light')
      end
    end

    describe '#root_device_name' do
      it 'delegates the method to heavy stemcell' do
        expect(heavy_stemcell).to receive(:root_device_name).and_return('THEROOOOT')
        expect(light_stemcell.root_device_name).to eq('THEROOOOT')
      end
    end

    describe '#image_id' do
      it 'delegates the method to heavy stemcell' do
        expect(heavy_stemcell).to receive(:image_id).and_return('ami-id')
        expect(light_stemcell.image_id).to eq('ami-id')
      end
    end
  end
end
