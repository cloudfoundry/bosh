require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::InfoController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }

      let(:temp_dir) { Dir.mktmpdir}
      let(:base_config) do
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
      let(:test_config) { base_config }
      let(:config) { Config.load_hash(test_config) }

      before { App.new(config) }

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
          info_response = Yajl::Parser.parse(last_response.body)
          expect(info_response['user']).to eq('admin')
        end

        it 'allows invalid credentials' do
          basic_authorize 'notadmin', 'admin'
          get '/'
          expect(last_response.status).to eq(200)
          info_response = Yajl::Parser.parse(last_response.body)
          expect(info_response['user']).to eq(nil)
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
          'user_authentication' => {
            'type' => 'basic',
            'options' => {},
          },
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

      context 'when configured with an external CPI' do
        let(:test_config) do
          cfg = base_config
          cfg['cloud'].delete('plugin')
          cfg['cloud']['provider'] = {
            'name' => 'test-cpi',
            'path' => '/path/to/test-cpi/bin/cpi'
          }
          cfg
        end

        it 'reports the cpi to be the external cpi executable path' do
          get '/'
          expect(Yajl::Parser.parse(last_response.body)['cpi']).to eq('test-cpi')
        end
      end

      context 'when configured to use UAA for user management' do
        let(:test_config) { base_config.merge(
          'user_management' => {'provider' => 'uaa', 'uaa' => {
            'url' => 'http://localhost:8080/uaa',
            'key' => 'super secret!',
          }}
        ) }

        it 'reports that uaa is the authentication method and excludes the secret key' do
          get '/'
          response_hash = Yajl::Parser.parse(last_response.body)
          expect(response_hash['user_authentication']).to eq(
              'type' => 'uaa',
              'options' => {'url' => 'http://localhost:8080/uaa'}
            )
        end
      end
    end
  end
end
