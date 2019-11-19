require 'spec_helper'
require 'json'

module Bosh::Blobstore
  describe GcscliBlobstoreClient do
    subject(:client) { described_class.new(options) }
    let!(:base_dir) { Dir.mktmpdir }
    before do
      allow(Dir).to receive(:tmpdir).and_return(base_dir)
      allow(SecureRandom).to receive_messages(uuid: 'FAKE_UUID')
      allow(Kernel).to receive(:system).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "--v", {:out => "/dev/null", :err => "/dev/null"}).and_return(true)
    end

    let(:options) do
      {
          bucket_name:       'test',
          storage_class:      'REGIONAL',
          gcscli_path:        '/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli'
      }
    end

    let(:expected_config_file) { File.join(base_dir, 'gcs_blobstore_config-FAKE_UUID') }
    let(:success_exit_status) { instance_double('Process::Status', exitstatus: 0, success?: true) }
    let(:not_existed_exit_status) { instance_double('Process::Status', exitstatus: 3, success?: true) }
    let(:failure_exit_status) { instance_double('Process::Status', exitstatus: 1, success?: false) }
    let(:object_id) { 'fo1' }
    let(:file_path) { File.join(base_dir, "temp-path-FAKE_UUID") }

    after { FileUtils.rm_rf(base_dir) }

    describe 'interface' do
      it_implements_base_client_interface
    end

    describe 'options' do
      let(:expected_options) do
        options.merge(
            {
                credentials_source: 'none'
            }
        ).reject { |k, v| k == :gcscli_path }
      end
      let (:stored_config_file) { File.new(expected_config_file).readlines }

      context 'when there is no gcscli' do
        it 'raises an error' do
          allow(Kernel).to receive(:system).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "--v", {:out => "/dev/null", :err => "/dev/null"}).and_return(false)
          expect { described_class.new(options) }.to raise_error(
              Bosh::Blobstore::BlobstoreError, 'Cannot find gcscli executable. Please specify gcscli_path parameter')
        end
      end

      context 'when gcscli exists' do
        before { described_class.new(options) }

        it 'should set default values to config file' do
          expect(File.exist?(expected_config_file)).to eq(true)
          expect(JSON.parse(stored_config_file[0], {:symbolize_names => true})).to eq(expected_options)
        end

        it 'should write the config file with reduced group and world permissions' do
          expect(File.stat(expected_config_file).mode).to eq(0100600)
        end

        it 'should set `none` as credentials_source' do
          expect(JSON.parse(stored_config_file[0])["credentials_source"]).to eq("none")
        end
      end

      context 'when gcscli_config_path option is provided' do
        let (:gcscli_config_path) { Dir::tmpdir }
        let (:config_file_options) do
          options.merge (
              {
                  gcscli_config_path: gcscli_config_path
              })
        end

        it 'creates config file with provided path' do
          described_class.new(config_file_options)
          expect(File.exist?(File.join(gcscli_config_path, 'gcs_blobstore_config-FAKE_UUID'))).to eq(true)
        end
      end
    end

    describe '#delete' do
      it 'should delete an object' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "-c", "#{expected_config_file}", "delete", "#{object_id}")
        client.delete(object_id)
      end

      it 'should show an error from gcscli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.delete(object_id) }.to raise_error(
            BlobstoreError, /error: 'error'/)
      end
    end

    describe '#exists?' do
      it 'should return true if gcscli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "-c", "#{expected_config_file}", "exists", "#{object_id}")

        expect(client.exists?(object_id)).to eq(true)
      end

      it 'should return false if gcscli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, not_existed_exit_status])
        expect(Open3).to receive(:capture3).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "-c", "#{expected_config_file}", "exists", "#{object_id}")
        expect(client.exists?(object_id)).to eq(false)
      end

      it 'should show an error from gcscli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
            BlobstoreError, /error: 'error'/)
      end
    end

    describe '#get' do
      it 'should raise on execution failure' do
        allow(Open3).to receive(:capture3).and_raise(Exception.new('something bad happened'))
        expect { client.get(object_id) }.to raise_error(
          BlobstoreError, /something bad happened/)
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "-c", "#{expected_config_file}", "get", "#{object_id}", "#{file_path}")
        client.get(object_id)
      end

      it 'should show an error from gcscli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.get(object_id) }.to raise_error(
            BlobstoreError, /Failed to download GCS object/)
      end
    end

    describe '#create' do
      it 'should take a string as argument' do
        expect(client).to receive(:store_in_gcs)
        client.create('foobar')
      end

      it 'should take a file as argument' do
        expect(client).to receive(:store_in_gcs)
        file = File.open(Tempfile.new('file'))
        client.create(file)
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        file = File.open(Tempfile.new('file'))
        expect(Open3).to receive(:capture3).with("/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli", "-c", "#{expected_config_file}", "put", "#{file.path}", "FAKE_UUID")
        client.create(file)
      end

      it 'should show an error ' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
            BlobstoreError, /Failed to create GCS object/)
      end

      it 'should show an error from gcscli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
            BlobstoreError, /error: 'error'/)
      end
    end

    describe '#sign_url' do
      it 'should return the signed url' do
        expect(Open3).to receive(:capture3)
          .with(
            '/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli',
            '-c',
            expected_config_file.to_s,
            'sign',
            object_id.to_s,
            'get',
            '24h',
          ).and_return(['https://signed-url', nil, success_exit_status])
        expect(subject.sign(object_id, 'get')).to eq('https://signed-url')
      end

      it 'should show an error from gcscli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.sign(object_id, 'get') }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end

      it 'provides properties to remove for agent settings' do
        expect(subject.redacted_credential_properties_list).to eq(%w[json_key credentials_source])
      end

      context 'encryption key present' do
        let(:options) do
          {
            bucket_name:    'test',
            storage_class:  'REGIONAL',
            gcscli_path:    '/var/vcap/packages/bosh-gcscli/bin/bosh-gcscli',
            encryption_key: 'z3DJQ+ft7Y//Yh3rnmyP+Xw9IUYw6BcurheJSarz6ks=',
          }
        end
        it 'can build encryption headers with correct hash' do
          expect(subject.signed_url_encryption_headers).to match(
                                                                'x-goog-encryption-algorithm' => 'AES256',
                                                                'x-goog-encryption-key' => 'z3DJQ+ft7Y//Yh3rnmyP+Xw9IUYw6BcurheJSarz6ks=',
                                                                'x-goog-encryption-key-sha256' => 'gUOk6XciSqMkKgZX2lkeaU/FTlVzUm2DOo8eUMEYHAE='
                                                            )
        end
      end
    end
  end
end
