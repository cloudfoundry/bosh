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
        instance_double('Bosh::Stemcell::Archive', infrastructure: 'aws')
      end

      let(:light_stemcell) do
        instance_double('Bosh::Stemcell::Aws::LightStemcell', write_archive: nil, path: 'fake light stemcell path')
      end

      let(:light_stemcell_stemcell) do
        instance_double('Bosh::Stemcell::Archive')
      end

      let(:candidate_build) { instance_double('Bosh::Dev::Build', upload_stemcell: nil) }

      let(:stemcell_path) { '/path/to/fake-stemcell.tgz' }

      before do
        Bosh::Stemcell::Archive.stub(:new).with(stemcell_path).and_return(stemcell)
        Bosh::Stemcell::Aws::LightStemcell.stub(:new).with(stemcell).and_return(light_stemcell)
        Bosh::Stemcell::Archive.stub(:new).with(light_stemcell.path).and_return(light_stemcell_stemcell)

        Build.stub(candidate: candidate_build)
      end

      it 'publishes the generated stemcell' do
        candidate_build.should_receive(:upload_stemcell).with(stemcell)

        publisher.publish(stemcell_path)
      end

      context 'when infrastructure is aws' do
        it 'publishes an aws light stemcell' do
          light_stemcell.should_receive(:write_archive)
          candidate_build.should_receive(:upload_stemcell).with(light_stemcell_stemcell)

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
