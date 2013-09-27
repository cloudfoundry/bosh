require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/stemcell_publisher'

module Bosh::Dev
  describe StemcellPublisher do
    include FakeFS::SpecHelpers

    describe '.for_candidate_build' do
      it 'news the publisher with a build' do
        build = double('build')
        Bosh::Dev::Build.stub(candidate: build)

        publisher = instance_double('Bosh::Dev::StemcellPublisher')
        described_class.should_receive(:new).with(build).and_return(publisher)
        described_class.for_candidate_build.should == publisher
      end
    end

    describe '#publish' do
      subject(:publisher) { described_class.new(build) }
      let(:build) { instance_double('Bosh::Dev::Build', upload_stemcell: nil) }

      before { Bosh::Stemcell::Aws::LightStemcell.stub(:new).with(stemcell).and_return(light_stemcell) }
      let(:stemcell) { instance_double('Bosh::Stemcell::Archive', infrastructure: 'aws') }
      let(:light_stemcell) do
        instance_double(
          'Bosh::Stemcell::Aws::LightStemcell',
          write_archive: nil,
          path: 'light-stemcell-path',
        )
      end

      before { Bosh::Stemcell::Archive.stub(:new).with(light_stemcell.path).and_return(light_stemcell_archive) }
      let(:light_stemcell_archive) { instance_double('Bosh::Stemcell::Archive') }

      before { Bosh::Stemcell::Archive.stub(:new).with(stemcell_path).and_return(stemcell) }
      let(:stemcell_path) { '/path/to/fake-stemcell.tgz' }

      it 'publishes the generated stemcell' do
        build.should_receive(:upload_stemcell).with(stemcell)
        publisher.publish(stemcell_path)
      end

      context 'when infrastructure is aws' do
        it 'publishes an aws light stemcell' do
          light_stemcell.should_receive(:write_archive)
          build.should_receive(:upload_stemcell).with(light_stemcell_archive)
          publisher.publish(stemcell_path)
        end
      end

      context 'when infrastructure is not aws' do
        before { stemcell.stub(infrastructure: 'vsphere') }

        it 'does nothing since other infrastructures do not have light stemcells' do
          light_stemcell.should_not_receive(:write_archive)
          publisher.publish(stemcell_path)
        end
      end
    end
  end
end
