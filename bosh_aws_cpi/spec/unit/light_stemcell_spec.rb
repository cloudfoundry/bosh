require 'cloud/aws/light_stemcell'

module Bosh::AwsCloud
  describe LightStemcell do
    let(:heavy_stemcell) { double('heavy stemcell', id: 'fake-ami-id') }
    let(:logger) { double('logger') }
    subject(:light_stemcell) { described_class.new(heavy_stemcell, logger) }

    describe '#delete' do
      it 'does not delete the light stemcell' do
        logger.stub(:info)
        heavy_stemcell.should_not_receive(:delete)
        light_stemcell.delete
      end

      it 'logs at INFO about the deletion' do
        logger.should_receive(:info).with("NoOP: Deleting light stemcell 'fake-ami-id'")
        light_stemcell.delete
      end
    end

    describe '#id' do
      it 'appends " light" to the id of heavy stemcell to distinguish the light stemcell from a heavy one' do
        heavy_stemcell.should_receive(:id).and_return('ami-id')
        light_stemcell.id.should eq('ami-id light')
      end
    end

    describe '#root_device_name' do
      it 'delegates the method to heavy stemcell' do
        heavy_stemcell.should_receive(:root_device_name).and_return('THEROOOOT')
        light_stemcell.root_device_name.should eq('THEROOOOT')
      end
    end

    describe '#image_id' do
      it 'delegates the method to heavy stemcell' do
        heavy_stemcell.should_receive(:image_id).and_return('ami-id')
        light_stemcell.image_id.should eq('ami-id')
      end
    end
  end
end
