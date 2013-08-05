require 'spec_helper'
require 'bosh/dev/stemcell_publisher'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellPublisher do
    include FakeFS::SpecHelpers

    subject(:publisher) do
      StemcellPublisher.new
    end

    describe '#publish' do
      let(:stemcell) do
        instance_double('Bosh::Stemcell::Stemcell', infrastructure: 'aws')
      end

      let(:light_stemcell) do
        instance_double('Bosh::Stemcell::Aws::LightStemcell', write_archive: nil, path: 'fake light stemcell path')
      end

      let(:light_stemcell_stemcell) do
        instance_double('Bosh::Stemcell::Stemcell')
      end

      let(:pipeline) { instance_double('Bosh::Dev::Pipeline', publish_stemcell: nil) }

      let(:stemcell_path) { '/path/to/fake-stemcell.tgz' }

      before do
        Bosh::Stemcell::Stemcell.stub(:new).with(stemcell_path).and_return(stemcell)
        Bosh::Stemcell::Aws::LightStemcell.stub(:new).with(stemcell).and_return(light_stemcell)
        Bosh::Stemcell::Stemcell.stub(:new).with(light_stemcell.path).and_return(light_stemcell_stemcell)

        Pipeline.stub(:new).and_return(pipeline)
      end

      it 'publishes the generated stemcell' do
        pipeline.should_receive(:publish_stemcell).with(stemcell)

        publisher.publish(stemcell_path)
      end

      context 'when infrastructure is aws' do
        it 'publishes an aws light stemcell' do
          light_stemcell.should_receive(:write_archive)
          pipeline.should_receive(:publish_stemcell).with(light_stemcell_stemcell)

          publisher.publish(stemcell_path)
        end
      end

      context 'when infrastructure is not aws' do
        before do
          stemcell.stub(:infrastructure).and_return('vsphere')
        end

        it 'does nothing since other infrastructures do not have light stemcells' do
          light_stemcell.should_not_receive(:write_archive)

          publisher.publish(stemcell_path)
        end
      end
    end
  end
end
