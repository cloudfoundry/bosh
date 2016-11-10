require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/stemcell_publisher'

module Bosh::Dev
  describe StemcellPublisher do
    include FakeFS::SpecHelpers

    subject(:publisher) { described_class.new(build) }

    let(:build) { instance_double('Bosh::Dev::Build', upload_stemcell: nil) }
    let(:bucket_name) { "fake-bucket" }
    before { allow(Bosh::Dev::Build).to receive(:candidate).with(bucket_name).and_return(build) }

    describe '.for_candidate_build' do
      let(:publisher) { instance_double('Bosh::Dev::StemcellPublisher') }

      it 'instantiates the publisher with a build' do
        expect(described_class).to receive(:new).with(build).and_return(publisher)
        expect(described_class.for_candidate_build(bucket_name)).to eq(publisher)
      end
    end

    describe '#publish' do
      let(:stemcell_path) { '/path/to/fake-stemcell.tgz' }
      let(:infrastructure) { 'vsphere' }
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', infrastructure: infrastructure) }
      before do
        allow(Bosh::Stemcell::Archive).to receive(:new).with(stemcell_path).and_return(stemcell_archive)
      end

      it 'publishes the generated stemcell' do
        expect(build).to receive(:upload_stemcell).with(stemcell_archive)
        publisher.publish(stemcell_path)
      end

      context 'when infrastructure is not aws' do
        let(:infrastructure) { 'vsphere' }

        it 'does nothing since other infrastructures do not have light stemcells' do
          publisher.publish(stemcell_path)
        end
      end
    end
  end
end
