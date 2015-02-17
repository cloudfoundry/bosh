require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::InfoController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(identity_provider) }

      let(:identity_provider) { Bosh::Director::Api::LocalIdentityProvider.new(Bosh::Director::Api::UserManager.new) }
      let(:temp_dir) { Dir.mktmpdir}
      let(:test_config) do
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
      end

      before { App.new(Config.load_hash(test_config)) }

      after { FileUtils.rm_rf(temp_dir) }

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      it 'allows unauthenticated access' do
        get '/'
        expect(last_response.status).to eq(200)
      end

      context 'when HTTP auth is provided' do
        it 'allows valid credentials' do
          basic_authorize 'admin', 'admin'
          get '/'
          expect(last_response.status).to eq(200)
        end

        it 'denies invalid credentials' do
          basic_authorize 'notadmin', 'admin'
          get '/'
          expect(last_response.status).to eq(401)
        end
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
             "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        expect(last_response.status).to eq(200)
      end

      it 'responds with expected json' do
        basic_authorize 'admin', 'admin'

        get '/'

        expected = {
          'name' => 'Test Director',
          'version' => "#{VERSION} (#{Config.revision})",
          'uuid' => Config.uuid,
          'user' => 'admin',
          'cpi' => 'dummy',
          'features' => {
            'dns' => {
              'status' => true,
              'extras' => {'domain_name' => 'bosh'}
            },
            'compiled_package_cache' => {
              'status' => true,
              'extras' => {'provider' => 'local'}
            },
            'snapshots' => {
              'status' => true
            }
          }
        }

        expect(Yajl::Parser.parse(last_response.body)).to eq(expected)
      end
    end
  end
end
