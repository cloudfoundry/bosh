require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::BackupsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:temp_dir) { Dir.mktmpdir}

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
