require 'spec_helper'

module VSphereCloud
  describe FileProvider do
    subject(:file_provider) { described_class.new(rest_client, vcenter_host) }

    let(:rest_client) { double('fake-rest-client') }
    let(:vcenter_host) { 'fake-vcenter-host' }

    let(:datacenter_name) { 'fake-datacenter-name 1' }
    let(:datastore_name) { 'fake-datastore-name 1' }
    let(:path) { 'fake-path' }

    describe '#fetch_file' do
      it 'gets specified file' do
        response_body = double('response_body')
        response = double('response', code: 200, body: response_body)
        expect(rest_client).to receive(:get).with(
          'https://fake-vcenter-host/folder/fake-path?'\
          'dcPath=fake-datacenter-name%201&dsName=fake-datastore-name%201'
        ).and_return(response)

        expect(
          file_provider.fetch_file(datacenter_name, datastore_name, path)
        ).to eq(response_body)
      end

      context 'when the current agent environment does not exist' do
        it 'returns nil' do
          expect(rest_client).to receive(:get).with(
            'https://fake-vcenter-host/folder/fake-path?'\
            'dcPath=fake-datacenter-name%201&dsName=fake-datastore-name%201'
          ).and_return(double('response', code: 404))

          expect(
            file_provider.fetch_file(datacenter_name, datastore_name, path)
          ).to be_nil
        end
      end

      context 'when vSphere cannot handle the request' do
        it 'retries then raises an error' do
          expect(rest_client).to receive(:get).with(
            'https://fake-vcenter-host/folder/fake-path?'\
            'dcPath=fake-datacenter-name%201&dsName=fake-datastore-name%201'
          ).twice.and_return(double('response', code: 500))

          expect {
            file_provider.fetch_file(datacenter_name, datastore_name, path)
          }.to raise_error
        end
      end
    end
  end
end
