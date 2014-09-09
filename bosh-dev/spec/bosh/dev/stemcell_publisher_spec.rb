require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/stemcell_publisher'

module Bosh::Dev
  describe StemcellPublisher do
    include FakeFS::SpecHelpers

    subject(:publisher) { described_class.new(build) }

    let(:build) { instance_double('Bosh::Dev::Build', upload_stemcell: nil) }
    before { allow(Bosh::Dev::Build).to receive(:candidate).and_return(build) }

    describe '.for_candidate_build' do
      let(:publisher) { instance_double('Bosh::Dev::StemcellPublisher') }

      it 'instantiates the publisher with a build' do
        expect(described_class).to receive(:new).with(build).and_return(publisher)
        expect(described_class.for_candidate_build).to eq(publisher)
      end
    end

    describe '#publish' do
      let(:stemcell_path) { '/path/to/fake-stemcell.tgz' }
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', infrastructure: 'aws') }
      before do
        allow(Bosh::Stemcell::Archive).to receive(:new).with(stemcell_path).and_return(stemcell_archive)
      end

      let(:light_stemcell) do
        instance_double(
          'Bosh::Stemcell::Aws::LightStemcell',
          write_archive: nil,
          path: 'light-stemcell-path',
        )
      end
      before do
        allow(Bosh::Stemcell::Aws::LightStemcell).to receive(:new).with(stemcell_archive).and_return(light_stemcell)
      end

      let(:light_stemcell_archive) { instance_double('Bosh::Stemcell::Archive') }
      before do
        allow(Bosh::Stemcell::Archive).to receive(:new).with(light_stemcell.path).and_return(light_stemcell_archive)
      end

      it 'publishes the generated stemcell' do
        expect(build).to receive(:upload_stemcell).with(stemcell_archive)
        publisher.publish(stemcell_path)
      end

      context 'when infrastructure is aws' do
        it 'publishes an aws light stemcell' do
          expect(light_stemcell).to receive(:write_archive)
          expect(build).to receive(:upload_stemcell).with(light_stemcell_archive)
          publisher.publish(stemcell_path)
        end
      end

      context 'when infrastructure is not aws' do
        before do
          allow(stemcell_archive).to receive(:infrastructure).and_return('vsphere')
        end

        it 'does nothing since other infrastructures do not have light stemcells' do
          expect(light_stemcell).not_to receive(:write_archive)
          publisher.publish(stemcell_path)
        end
      end
    end
  end
end
