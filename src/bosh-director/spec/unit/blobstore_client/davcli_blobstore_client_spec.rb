require 'spec_helper'

module Bosh::Blobstore
  describe DavcliBlobstoreClient do
    subject { described_class.new(options) }
    let(:options) do
      {
        endpoint: 'https://localhost',
        user: 'john',
        password: 'smith',
        davcli_path: davcli_path,
        tls: {
          cert: {
            ca: 'FAKE_CA_PEM',
          },
        },
      }
    end
    let!(:base_dir) { Dir.mktmpdir }
    let(:object_id) { 'foobar' }
    let(:failure_exit_status) { instance_double('Process::Status', exitstatus: 1, success?: false) }
    let(:success_exit_status) { instance_double('Process::Status', exitstatus: 0, success?: true) }
    let(:not_existed_exit_status) { instance_double('Process::Status', exitstatus: 3, success?: true) }
    let(:expected_config_file) { File.join(base_dir, 'davcli-blobstore-config-FAKE_UUID') }
    let(:davcli_path) { '/var/vcap/packages/davcli/bin/davcli' }

    before do
      allow(Dir).to receive(:tmpdir).and_return(base_dir)
      allow(SecureRandom).to receive_messages(uuid: 'FAKE_UUID')
      allow(Open3).to receive(:capture3)
      allow(Kernel).to receive(:system)
        .with('/var/vcap/packages/davcli/bin/davcli', '-v', out: '/dev/null', err: '/dev/null').and_return(true)
    end

    let(:file_path) { File.join(base_dir, 'temp-path-FAKE_UUID') }

    after { FileUtils.rm_rf(base_dir) }

    describe 'interface' do
      it_implements_base_client_interface
    end

    describe 'options' do
      let(:expected_options) do
        {
          endpoint: 'https://localhost',
          user: 'john',
          password: 'smith',
          secret: nil,
          tls: {
            cert: {
              ca: 'FAKE_CA_PEM',
            },
          },
        }
      end
      let(:stored_config_file) { File.new(expected_config_file).readlines }

      context 'when there is no davcli' do
        it 'raises an error' do
          allow(Kernel).to receive(:system).with(davcli_path.to_s, '-v', out: '/dev/null', err: '/dev/null').and_return(false)
          expect { described_class.new(options) }.to raise_error(
            Bosh::Blobstore::BlobstoreError, 'Cannot find davcli executable. Please specify davcli_path parameter'
          )
        end
      end

      context 'when davcli exists' do
        before { described_class.new(options) }

        it 'should set default values to config file' do
          expect(File.exist?(expected_config_file)).to eq(true)
          expect(JSON.parse(stored_config_file[0], symbolize_names: true)).to eq(expected_options)
        end

        it 'should write the config file with reduced group and world permissions' do
          expect(File.stat(expected_config_file).mode).to eq(0o100600)
        end
      end

      context 'when davcli_config_path option is provided' do
        let(:davcli_config_path) { File.join(base_dir, 'tmp') }
        let(:config_file_options) { options.merge(davcli_config_path: davcli_config_path) }

        it 'creates config file with provided path' do
          described_class.new(config_file_options)
          expect(File.exist?(File.join(davcli_config_path, 'davcli-blobstore-config-FAKE_UUID'))).to eq(true)
        end
      end
    end

    describe '#get' do
      it 'should have correct parameters' do
        expect(Open3).to receive(:capture3)
          .with(davcli_path.to_s, '-c', expected_config_file.to_s, 'get', object_id.to_s, file_path.to_s)
          .and_return([nil, nil, success_exit_status])

        subject.get(object_id)
      end

      it 'should show an error from davcli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.get(object_id) }.to raise_error(
          BlobstoreError, /Failed to download blob/
        )
      end

      it 'should raise a NotFound error when the key does not exist' do
        allow(Open3).to receive(:capture3).and_return(['404 Not Found', nil, failure_exit_status])
        expect { subject.get(object_id) }.to raise_error(
          NotFound, "Blobstore object '#{object_id}' not found"
        )
      end
    end

    describe '#create' do
      it 'should take a string as argument' do
        expect(subject).to receive(:store_in_webdav)
        subject.create('foobar')
      end

      it 'should take a file as argument' do
        expect(subject).to receive(:store_in_webdav)
        file = File.open(Tempfile.new('file'))
        subject.create(file)
      end

      it 'should have correct parameters' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        file = File.open(Tempfile.new('file'))
        expect(Open3).to receive(:capture3)
          .with(davcli_path.to_s, '-c', expected_config_file.to_s, 'put', file.path.to_s, 'FAKE_UUID')
        subject.create(file)
      end

      it 'should show an error ' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, failure_exit_status])
        expect { subject.create(object_id) }.to raise_error(
          BlobstoreError, /Failed to upload blob/
        )
      end

      it 'should show an error from davcli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.create(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#delete' do
      it 'should delete an object' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with(davcli_path.to_s, '-c', expected_config_file.to_s, 'delete', object_id.to_s)
        subject.delete(object_id)
      end

      it 'should show an error from davcli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.delete(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#exists?' do
      it 'should return true if davcli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, success_exit_status])
        expect(Open3).to receive(:capture3).with(davcli_path.to_s, '-c', expected_config_file.to_s, 'exists', object_id.to_s)
        expect(subject.exists?(object_id)).to eq(true)
      end

      it 'should return false if davcli reported so' do
        allow(Open3).to receive(:capture3).and_return([nil, nil, not_existed_exit_status])
        expect(Open3).to receive(:capture3).with(davcli_path.to_s, '-c', expected_config_file.to_s, 'exists', object_id.to_s)
        expect(subject.exists?(object_id)).to eq(false)
      end

      it 'should show an error from davcli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.create(object_id) }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end
    end

    describe '#sign_url' do
      it 'should return the signed url' do
        expect(Open3).to receive(:capture3).with(davcli_path.to_s, '-c', expected_config_file.to_s, 'sign', object_id.to_s, 'get', '24h')
          .and_return(['https://signed-url', nil, success_exit_status])
        expect(subject.sign(object_id, 'get')).to eq('https://signed-url')
      end

      it 'should show an error from davcli' do
        allow(Open3).to receive(:capture3).and_return([nil, 'error', failure_exit_status])
        expect { subject.sign(object_id, 'get') }.to raise_error(
          BlobstoreError, /error: 'error'/
        )
      end

      it 'provides properties to remove for agent settings' do
        expect(subject.credential_properties).to eq(%w[user password secret])
      end
    end
  end
end
