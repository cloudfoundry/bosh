require 'spec_helper'
require 'json'

module Bosh::Blobstore
  describe S3cliBlobstoreClient do
    subject(:client) { described_class.new(options) }
    let!(:base_dir) { Dir.mktmpdir }
    before do
      allow(Dir).to receive(:tmpdir).and_return(base_dir)
      allow(SecureRandom).to receive_messages(uuid: 'FAKE_UUID')
      allow(Kernel).to receive(:system).with('/var/vcap/packages/s3cli/bin/s3cli', '--v', out: '/dev/null', err: '/dev/null').and_return(true)
    end

    let(:options) do
      {
        bucket_name: 'test',
        access_key_id: 'KEY',
        secret_access_key: 'SECRET',
        s3cli_path: '/var/vcap/packages/s3cli/bin/s3cli',
        host_style: true,
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
        options.merge(
          use_ssl: true,
          ssl_verify_peer: true,
          credentials_source: 'none',
          host_style: true,
        ).reject { |k, _v| k == :s3cli_path }
      end
      let(:stored_config_file) { File.new(expected_config_file).readlines }

      context 'when there is no s3cli' do
        it 'raises an error' do
          allow(Kernel).to receive(:system).with('/var/vcap/packages/s3cli/bin/s3cli', '--v', out: '/dev/null', err: '/dev/null').and_return(false)
          expect { described_class.new(options) }.to raise_error(
            Bosh::Blobstore::BlobstoreError, 'Cannot find s3cli executable. Please specify s3cli_path parameter'
          )
        end
      end

      context 'when s3cli exists' do
        before { described_class.new(options) }

        it 'should set default values to config file' do
          expect(File.exist?(expected_config_file)).to eq(true)
          expect(JSON.parse(stored_config_file[0], symbolize_names: true)).to eq(expected_options)
        end

        it 'should write the config file with reduced group and world permissions' do
          expect(File.stat(expected_config_file).mode).to eq(0o100600)
        end

        it 'should set `none` as credentials_source' do
          expect(JSON.parse(stored_config_file[0])['credentials_source']).to eq('none')
        end
      end

      context 'when using env_or_profile' do
        let(:env_options) do
          options.merge(
            credentials_source: 'env_or_profile',
          ).reject { |k, _v| %i[access_key_id secret_access_key].include? k }
        end
        it 'should allow access_key_id and secret_access_key to be unset' do
          expect(described_class.new(env_options).validate!(env_options, 4)).to be_nil
        end
      end

      context 'when not using env_or_profile' do
        let(:bad_options) do
          options.reject { |k, _v| %i[access_key_id secret_access_key].include? k }
        end
        it 'should require access_key_id and secret_access_key to be set' do
          expect do
            described_class.new(bad_options).validate!(bad_options, 4)
          end.to raise_error(
            Bosh::Director::BadConfig,
            'Inconsistent blobstore configuration: ["access_key_id", "secret_access_key"] are required',
          )
        end
      end

      context 'when s3cli_config_path option is provided' do
        let(:s3cli_config_path) { Dir.tmpdir }
        let(:config_file_options) do
          options.merge(
              {
                s3cli_config_path: s3cli_config_path,
              })
        end

        it 'creates config file with provided path' do
          described_class.new(config_file_options)
          expect(File.exist?(File.join(s3cli_config_path, 'blobstore-config'))).to eq(true)
        end
      end

      context 'when swift_auth_account is provided' do
        it 'adds it to the config file' do
          described_class.new(options.merge(
            {
              swift_auth_account: 'the_swift_auth_account',
            })
          )

          expect(JSON.parse(stored_config_file[0])['swift_auth_account']).to eq('the_swift_auth_account')
        end
      end

      context 'when swift_temp_url_key is provided' do
        it 'adds it to the config file' do
          described_class.new(options.merge(
            {
              swift_temp_url_key: 'the_swift_temp_url_key',
            })
          )

          expect(JSON.parse(stored_config_file[0])['swift_temp_url_key']).to eq('the_swift_temp_url_key')
        end
      end

      context 'when openstack_blobstore_type is provided' do
        it 'adds it to the config file' do
          described_class.new(options.merge(
            {
              openstack_blobstore_type: 'the_openstack_blobstore_type',
            })
          )

          expect(JSON.parse(stored_config_file[0])['openstack_blobstore_type']).to eq('the_openstack_blobstore_type')
        end
      end
    end

    describe '#delete' do
      it 'should delete an object' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'delete', object_id.to_s)
        client.delete(object_id)
      end

      it 'should show an error from s3cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.delete(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#exists?' do
      it 'should return true if s3cli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'exists', object_id.to_s)

        expect(client.exists?(object_id)).to eq(true)
      end

      it 'should return false if s3cli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, not_existed_exit_status])
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'exists', object_id.to_s)
        expect(client.exists?(object_id)).to eq(false)
      end

      it 'should show an error from s3cli' do
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
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'get', object_id.to_s, file_path.to_s)
        client.get(object_id)
      end

      it 'should show an error from s3cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.get(object_id) }.to raise_error(
          BlobstoreError, /Failed to download S3 object/
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
        expect(client).to receive(:store_in_s3)
        client.create('foobar')
      end

      it 'should take a file as argument' do
        expect(client).to receive(:store_in_s3)
        file = File.open(Tempfile.new('file'))
        client.create(file)
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        file = File.open(Tempfile.new('file'))
        expect(Open3).to receive(:capture3).with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'put', file.path.to_s, 'FAKE_UUID')
        client.create(file)
      end

      it 'should show an error ' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
          BlobstoreError, /Failed to create S3 object/
        )
      end

      it 'should show an error from s3cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { client.create(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#sign_url' do
      it 'should return the signed url' do
        expect(Open3).to receive(:capture3)
          .with('/var/vcap/packages/s3cli/bin/s3cli', '-c', expected_config_file.to_s, 'sign', object_id.to_s, 'get', '24h')
          .and_return(['https://signed-url', nil, success_exit_status])
        expect(subject.sign(object_id, 'get')).to eq('https://signed-url')
      end

      it 'should show an error from s3cli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.sign(object_id, 'get') }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end

      it 'provides properties to remove for agent settings' do
        expect(subject.redacted_credential_properties_list).to eq(%w[access_key_id secret_access_key credentials_source])
      end
    end

    describe '#headers' do
        it 'returns empty headers' do
          expect(subject.headers).to be_empty
        end
    end
  end
end
