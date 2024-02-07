require 'spec_helper'
require 'json'

module Bosh::Blobstore
  describe AzurestoragecliBlobstoreClient do
    subject(:client) { described_class.new(options) }
    let!(:base_dir) { Dir.mktmpdir }
    before do
      allow(Dir).to receive(:tmpdir).and_return(base_dir)
      allow(SecureRandom).to receive_messages(uuid: 'FAKE_UUID')
      allow(Kernel).to receive(:system).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '--v', out: '/dev/null', err: '/dev/null').and_return(true)
    end

    let(:options) do
      {
        container_name: 'test',
        account_name: 'NAME',
        account_key: 'SECRET',
        azure_storage_cli_path: '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli',
      }
    end
    let(:expected_config_file) { File.join(base_dir, 'blobstore-config') }
    let(:success_exit_status) { instance_double('Process::Status', exitstatus: 0, success?: true) }
    let(:not_existed_exit_status) { instance_double('Process::Status', exitstatus: 3, success?: true) }
    let(:failure_exit_status) { instance_double('Process::Status', exitstatus: 1, success?: false) }
    let(:object_id) { 'fo1' }
    let(:file_path) { File.join(base_dir, 'temp-path-FAKE_UUID') }

    after { FileUtils.rm_rf(base_dir) }

    describe 'interface' do
      it_implements_base_client_interface
    end

    describe 'options' do
      let(:expected_options) do
        {
          'container_name' => 'test',
          'account_name' => 'NAME',
          'account_key' => 'SECRET'
        }
      end
      let(:stored_config_file) { File.new(expected_config_file).readlines }

      context 'when there is no azure-storage-cli' do
        it 'raises an error' do
          allow(Kernel).to receive(:system).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '--v', out: '/dev/null', err: '/dev/null').and_return(false)
          expect { described_class.new(options) }.to raise_error(
            Bosh::Blobstore::BlobstoreError, 'Cannot find azure-storage-cli executable. Please specify azure_storage_cli_path parameter'
          )
        end
      end

      context 'when azure-storage-cli exists' do
        before { described_class.new(options) }

        it 'should set default values to config file' do
          expect(File.exist?(expected_config_file)).to eq(true)
          expect(JSON.parse(stored_config_file[0])).to eq(expected_options)
        end

        it 'should write the config file with reduced group and world permissions' do
          expect(File.stat(expected_config_file).mode).to eq(0o100600)
        end
      end

      context 'when azure_storage_cli_config_path option is provided' do
        let(:azure_storage_cli_config_path) { Dir.tmpdir }
        let(:config_file_options) do
          options.merge (
              {
                azure_storage_cli_config_path: azure_storage_cli_config_path,
              })
        end

        it 'creates config file with provided path' do
          described_class.new(config_file_options)
          expect(File.exist?(File.join(azure_storage_cli_config_path, 'blobstore-config'))).to eq(true)
        end
      end
    end

    describe '#delete' do
      it 'should delete an object' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'delete', object_id.to_s)
        client.delete(object_id)
      end

      it 'should show an error from azure-storage-cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.delete(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#exists?' do
      it 'should return true if azure-storage-cli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'exists', object_id.to_s)

        expect(client.exists?(object_id)).to eq(true)
      end

      it 'should return false if azure-storage-cli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, not_existed_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'exists', object_id.to_s)
        expect(client.exists?(object_id)).to eq(false)
      end

      it 'should show an error from azure-storage-cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#get' do
      it 'should raise on execution failure' do
        allow(Open3).to receive(:capture3).and_raise(Exception.new('something bad happened'))
        expect { client.get(object_id) }.to raise_error(
          BlobstoreError, /something bad happened/
        )
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'get', object_id.to_s, file_path.to_s)
        client.get(object_id)
      end

      it 'should show an error from azure-storage-cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.get(object_id) }.to raise_error(
          BlobstoreError, /Failed to download azure storage account object/
        )
      end

      it 'should raise a NotFound error if the key does not exist' do
        allow(Open3).to receive(:capture3).and_return([nil, 'NoSuchKey', failure_exit_status])
        expect { client.get(object_id) }.to raise_error(
          NotFound, "Blobstore object '#{object_id}' not found"
        )
      end
    end

    describe '#create' do
      it 'should take a string as argument' do
        expect(client).to receive(:store_in_azure_storage)
        client.create('foobar')
      end

      it 'should take a file as argument' do
        expect(client).to receive(:store_in_azure_storage)
        file = File.open(Tempfile.new('file'))
        client.create(file)
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        file = File.open(Tempfile.new('file'))
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'put', file.path.to_s, 'FAKE_UUID')
        client.create(file)
      end

      it 'should show an error ' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
          BlobstoreError, /Failed to create azure storage account object/
        )
      end

      it 'should show an error from azure-storage-cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#sign_url' do
      it 'should return the signed url' do
        expect(Open3).to receive(:capture3)
          .with('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli', '-c', expected_config_file.to_s, 'sign', object_id.to_s, 'get', '24h')
          .and_return(['https://signed-url', nil, success_exit_status])
        expect(subject.sign(object_id, 'get')).to eq('https://signed-url')
      end

      it 'should show an error from azure-storage-cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.sign(object_id, 'get') }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end

      it 'provides properties to remove for agent settings' do
        expect(subject.redacted_credential_properties_list).to eq(%w[account_key])
      end
    end

    describe 'signed url encryption headers - not implemented' do
      let(:options) do
        {
          container_name: 'test',
          account_name: 'NAME',
          account_key: 'SECRET',
          azure_storage_cli_path: '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli',
        }
      end

      it 'should not produce headers based on encryption options' do
        expect(subject.signed_url_encryption_headers).to be_nil
      end

      it 'does not support encryption' do
        expect(subject.encryption?).to eq(false)
      end
    end

    context 'put headers present' do
      let(:options) do
        {
          container_name: 'test',
          account_name: 'NAME',
          account_key: 'SECRET',
          azure_storage_cli_path: '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli',
        }
      end

      it '.put_headers? returns true' do
        expect(subject.put_headers?).to be(true)
      end

      it '.put_headers returns a hash of headers' do
        expect(subject.put_headers).to eq({ 'x-ms-blob-type' => 'blockblob' })
      end
    end

  end
end
