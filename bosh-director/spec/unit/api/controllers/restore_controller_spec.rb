require 'spec_helper'

module Bosh::Director
  module Api
    describe Controllers::RestoreController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }
      let(:test_config) do
        config = Psych.load(spec_asset('test-director-config.yml'))
        config['db'].merge!({
          'user' => 'fake-user',
          'password' => 'fake-password',
          'host' => 'fake-host',
        })
        config
      end

      before { App.new(config) }

      it 'requires auth' do
        post '/', 'fake-data', { 'CONTENT_TYPE' => 'multipart/form-data' }
        expect(last_response.status).to eq(401)
      end

      describe 'POST', '/' do
        before { authorize 'admin', 'admin' }

        it 'restores DB' do
          expect_any_instance_of(RestoreManager).to receive(:restore_db).with('/path/to/db_dump.tgz')

          post '/', { 'nginx_upload_path' => '/path/to/db_dump.tgz'}, { 'CONTENT_TYPE' => 'multipart/form-data' }
          expect(last_response.status).to eq(202)
        end
      end
    end
  end
end
