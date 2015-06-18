require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::BackupsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }
      let(:temp_dir) { Dir.mktmpdir}
      let(:test_config) {
        blobstore_dir = File.join(temp_dir, 'blobstore')
        FileUtils.mkdir_p(blobstore_dir)

        config = Psych.load(spec_asset('test-director-config.yml'))
        config['dir'] = temp_dir
        config['blobstore'] = {
          'provider' => 'local',
          'options' => {'blobstore_path' => blobstore_dir}
        }
        config['snapshots']['enabled'] = true
        config
      }

      after { FileUtils.rm_rf(temp_dir) }

      it 'requires auth' do
        get '/'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
           "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        expect(last_response.status).to eq(404)
      end

      describe 'API calls' do
        before(:each) { basic_authorize 'admin', 'admin' }

        describe 'snapshots' do
          before do
            deployment = Models::Deployment.make(name: 'mycloud')

            instance = Models::Instance.make(deployment: deployment, job: 'job', index: 0)
            disk = Models::PersistentDisk.make(disk_cid: 'disk0', instance: instance, active: true)
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap0a')

            instance = Models::Instance.make(deployment: deployment, job: 'job', index: 1)
            disk = Models::PersistentDisk.make(disk_cid: 'disk1', instance: instance, active: true)
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1a')
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1b')
          end

          describe 'backup' do
            describe 'creating' do
              before { App.new(config) }

              it 'returns a successful response' do
                post '/'
                expect_redirect_to_queued_task(last_response)
              end
            end

            describe 'fetching' do
              it 'returns the backup tarball' do
                Dir.mktmpdir do |temp|
                  backup_file = File.join(temp, 'backup.tgz')
                  FileUtils.touch(backup_file)
                  allow_any_instance_of(BackupManager).to receive_messages(destination_path: backup_file)

                  get '/'
                  expect(last_response.status).to eq 200
                end
              end

              it 'returns file not found for missing tarball' do
                get '/'
                expect(last_response.status).to eq 404
              end
            end
          end
        end
      end
    end
  end
end
