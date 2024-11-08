require 'spec_helper'
require 'nats_sync/users_sync'
require 'rest-client'

module NATSSync
  describe UsersSync do
    before do
      allow(NATSSync).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:error)
      allow(logger).to receive(:info)
      allow(Open3).to receive(:capture2e).and_return(['Success', capture_status])
    end

    subject { UsersSync.new(nats_config_file_path, bosh_config, nats_executable, nats_server_pid_file) }

    let(:logger) { double('Logger') }
    let(:capture_status) { instance_double(Process::Status, success?: true) }
    let(:nats_config_file) { Tempfile.new('nats_config.json') }
    let(:nats_config_file_path) { nats_config_file.path }
    let(:nats_executable) { '/var/vcap/packages/nats/bin/nats-server' }
    let(:nats_server_pid_file) { '/var/vcap/sys/run/bpm/nats/nats.pid' }
    let(:bosh_config) do
      { 'url' => url,
        'user' => user,
        'password' => password,
        'client_id' => client_id,
        'client_secret' => client_secret,
        'ca_cert' => ca_cert,
        'director_subject_file' => director_subject_file,
        'hm_subject_file' => hm_subject_file }
    end
    let(:url) { 'http://127.0.0.1:25555' }
    let(:user) { 'admin' }
    let(:password) { 'admin' }
    let(:client_id) { 'client_id' }
    let(:client_secret) { 'client_secret' }
    let(:ca_cert) { 'ca_cert' }
    let(:director_subject_file) { sample_director_subject }
    let(:hm_subject_file) { sample_hm_subject }
    let(:director_subject) { 'C=USA, O=Cloud Foundry, CN=default.director.bosh-internal' }
    let(:hm_subject) { 'C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal' }
    let(:bosh_vms_subject) { 'C=USA, O=Cloud Foundry, CN=%s.bosh-internal' }
    let(:auth_provider) { class_double('NATSSync::AuthProvider').as_stubbed_const }
    let(:auth_provider_double) { instance_double(NATSSync::AuthProvider) }
    let(:deployments_json) do
      '[
  {
    "name": "deployment-1",
    "cloud_config": "none",
    "releases": [
      {
        "name": "cf",
        "version": "222"
      },
      {
        "name": "cf",
        "version": "223"
      }
    ],
    "stemcells": [
      {
        "name": "bosh-warden-boshlite-ubuntu-xenial-go_agent",
        "version": "621.74"
      },
      {
        "name": "bosh-warden-boshlite-ubuntu-xenial-go_agent",
        "version": "456.112"
      }
    ]
  }
]'
    end
    let(:vms_json) do
      '[
  {
    "agent_id":"fef068d8-bbdd-46ff-b4a5-bf0838f918d9",
    "cid":"e975f3e6-a979-40c3-723a-a30817944ae4",
    "job":"debug",
    "index":0,
    "id":"9cb7120d-d817-40f5-9410-d2b6f01ba746",
    "az":"z1",
    "ips":[],
    "vm_created_at":"2022-05-25T20:54:18Z",
    "active":false,
    "permanent_nats_credentials": true
  },
  {
    "agent_id":"c5e7c705-459e-41c0-b640-db32d8dc6e71",
    "cid":"e975f3e6-a979-40c3-723a-a30817944ae4",
    "job":"debug",
    "index":0,
    "id":"209b96c8-e482-43c7-9f3e-04de9f93c535",
    "az":"z1",
    "ips":[],
    "vm_created_at":"2022-05-25T20:54:18Z",
    "active":false,
    "permanent_nats_credentials": true
  }
]'
    end
    let(:info_json) do
      '{
  "name": "bosh-lite",
  "uuid": "4c0aac87-f823-48e4-b571-ddb47e4b772b",
  "version": "272.3.0 (00000000)",
  "user": null,
  "cpi": "warden_cpi",
  "stemcell_os": "ubuntu-bionic",
  "stemcell_version": "1.84",
  "user_authentication": {
    "type": "uaa",
    "options": {
      "url": "https://192.168.56.6:8443",
      "urls": [
        "https://192.168.56.6:8443"
      ]
    }
  },
  "features": {
    "local_dns": {
      "status": true,
      "extras": {
        "domain_name": "bosh"
      }
    },
    "snapshots": {
      "status": false
    },
    "config_server": {
      "status": true,
      "extras": {
        "urls": [
          "https://192.168.56.6:8844/api/"
        ]
      }
    }
  }
}'
    end

    describe '#execute_nats_sync' do
      before do
        stub_request(:get, "#{url}/info")
          .to_return(status: 200, body: info_json)
        stub_request(:get, "#{url}/deployments")
          .with(headers: { 'Authorization' => 'Bearer xyz' })
          .to_return(status: 200, body: deployments_json)
        allow(auth_provider).to receive(:new).and_return(auth_provider_double)
        allow(auth_provider_double).to receive(:auth_header).and_return('Bearer xyz')
        File.open(nats_config_file_path, 'w') do |f|
          f.write('{}')
        end
      end

      describe 'when UAA is not deployed and the BOSH API is not available' do
        before do
          stub_request(:get, "#{url}/deployments")
            .with(headers: { 'Authorization' => 'Bearer xyz' })
            .to_return(status: 401, body: 'Unauthorized')
        end

        describe 'and the authentication file is empty' do
          it 'should write the basic bosh configuration' do
            expect(JSON.parse(File.read(nats_config_file_path)).empty?).to be true
            subject.execute_users_sync
            file = File.read(nats_config_file_path)
            data_hash = JSON.parse(file)
            expect(data_hash['authorization']['users'])
              .to include(include('user' => director_subject))
            expect(data_hash['authorization']['users'])
              .to include(include('user' => hm_subject))
            expect(data_hash['authorization']['users'].length).to eq(2)
          end
        end

        describe 'and the authentication file is corrupted' do
          before do
            File.open(nats_config_file_path, 'w') do |f|
              f.write('{invalidchar')
            end
          end
          it 'should write the basic bosh configuration' do
            subject.execute_users_sync
            file = File.read(nats_config_file_path)
            data_hash = JSON.parse(file)
            expect(data_hash['authorization']['users'])
              .to include(include('user' => director_subject))
            expect(data_hash['authorization']['users'])
              .to include(include('user' => hm_subject))
            expect(data_hash['authorization']['users'].length).to eq(2)
          end
        end

        describe 'and the authentication file is not empty' do
          before do
            File.open(nats_config_file_path, 'w') do |f|
              f.write('{"authorization": {"users": [{"user": "foo"}]}}')
            end
          end
          it 'should not overwrite the authentication file' do
            subject.execute_users_sync
            file = File.read(nats_config_file_path)
            data_hash = JSON.parse(file)
            expect(data_hash).to eq({ 'authorization' => { 'users' => [{ 'user' => 'foo' }] } })
          end
        end
      end

      describe 'when there are no deployments with running vms in Bosh' do
        let(:deployments_json) { '[]' }

        it 'should write the basic bosh configuration ' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .to include(include('user' => director_subject))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => hm_subject))
          expect(data_hash['authorization']['users'].length).to eq(2)
        end
      end

      describe 'when there are deployments with running vms in Bosh' do
        before do
          stub_request(:get, "#{url}/deployments/deployment-1/vms")
            .with(headers: { 'Authorization' => 'Bearer xyz' })
            .to_return(status: 200, body: vms_json)
        end

        it 'logs when it is starting and finishing' do
          expect(logger).to receive(:info).with('Executing NATS Users Synchronization')
          expect(logger).to receive(:info).with('Finishing NATS Users Synchronization')

          subject.execute_users_sync
        end

        it 'should write the right number of users to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'].length).to eq(4)
        end

        it 'should write the right agent_ids to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .to include(include('user' => director_subject))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => hm_subject))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(bosh_vms_subject, 'fef068d8-bbdd-46ff-b4a5-bf0838f918d9.agent')))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(bosh_vms_subject, 'c5e7c705-459e-41c0-b640-db32d8dc6e71.agent')))
        end

        it 'should not write the wrong ids to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(bosh_vms_subject, '9cb7120d-d817-40f5-9410-d2b6f01ba746.agent')))
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(bosh_vms_subject, '209b96c8-e482-43c7-9f3e-04de9f93c535.agent')))
        end

        it 'should restart the nats process' do
          expect(Open3).to receive(:capture2e).with("#{nats_executable} --signal reload=#{nats_server_pid_file}")
          subject.execute_users_sync
        end

        describe 'when there is a previous configuration file with the same users' do
          before do
            vms =
              [
                {
                  'permanent_nats_credentials' => true,
                  'agent_id' => 'fef068d8-bbdd-46ff-b4a5-bf0838f918d9',
                },
                {
                  'permanent_nats_credentials' => true,
                  'agent_id' => 'c5e7c705-459e-41c0-b640-db32d8dc6e71',
                },
              ]

            write_config_file(vms)
          end

          it 'should not restart the NATs process' do
            expect(Open3).not_to receive(:capture2e)
            subject.execute_users_sync
          end
        end

        describe 'when there is a previous configuration file with different users' do
          before do
            vms =
              [
                {
                  'permanent_nats_credentials' => true,
                  'agent_id' => 'fef068d8-bbdd-46ff-b4a5-bf0838f918d9',
                },
                {
                  'permanent_nats_credentials' => true,
                  'agent_id' => '209b96c8-e482-43c7-8f3e-04de9f93c535',
                },
              ]
            write_config_file(vms)
          end

          it 'should restart the NATs process' do
            expect(Open3).to receive(:capture2e).with("#{nats_executable} --signal reload=#{nats_server_pid_file}")
            subject.execute_users_sync
          end
        end

        describe 'when there are running vms in Bosh and there are is no subject information for hm or the director' do
          let(:director_subject_file) { '/file/nonexistent1' }
          let(:hm_subject_file) { '/file/nonexistent2' }

          it 'should write the right number of users to the NATs configuration file in the given path' do
            subject.execute_users_sync
            file = File.read(nats_config_file_path)
            data_hash = JSON.parse(file)
            expect(data_hash['authorization']['users'].length).to eq(2)
          end

          it 'should not write the configuration for the bosh director or the bosh monitor' do
            subject.execute_users_sync
            file = File.read(nats_config_file_path)
            data_hash = JSON.parse(file)
            expect(data_hash['authorization']['users'])
              .not_to include(include('user' => hm_subject))
            expect(data_hash['authorization']['users'])
              .not_to include(include('user' => director_subject))
          end
        end

        describe 'when reloading the NATs server fails' do
          let(:capture_status) { instance_double(Process::Status, success?: false) }
          before do
            allow(Open3).to receive(:capture2e).and_return(['Failed to reload NATs server', capture_status])
          end

          it 'should raise an error' do
            expect { subject.execute_users_sync }.to raise_error(RuntimeError, /Failed to reload NATs server/)
          end
        end
      end

      def write_config_file(vms)
        File.open(nats_config_file_path, 'w') do |f|
          f.write(JSON.unparse(NatsAuthConfig.new(vms, director_subject, hm_subject).create_config))
        end
      end
    end
  end
end
