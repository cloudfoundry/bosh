require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DirectorController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      before { App.new(config) }

      context 'director/certificate_expiry' do
        context 'when a non-authorized user asks for the certificate expiry' do
          it 'requires auth' do
            get '/certificate_expiry'
            expect(last_response.status).to eq(401)
          end
        end

        context 'when asked for certificate expiry for the director' do
          let(:config_file) { Config.director_certificate_expiry_json_path }

          before { FileUtils.mkdir_p(File.dirname(config_file)) }
          after { FileUtils.rm_f(config_file) }

          context 'when queried as admin' do
            before { authorize('admin', 'admin') }

            it 'it responds with the expiry date and days left' do
              not_after = Time.now + (24 * 60 * 60 * 365)
              json = {
                'director.abc.certificate': not_after.utc.iso8601,
                'director.abc.ca': '0',
              }.to_json

              File.open(config_file, 'w') { |f| f.write(json) }

              expected = [{
                'certificate_path' => 'director.abc.certificate',
                'expiry' => not_after.utc.iso8601,
                'days_left' => 364,
              }]

              get '/certificate_expiry'

              expect(JSON.parse(last_response.body)).to eq(expected)
            end
          end

          context 'when queried as a reader' do
            before { authorize('reader', 'reader') }

            it 'it responds with the expiry date and days left' do
              not_after = Time.now + (24 * 60 * 60 * 365)
              json = {
                'director.abc.certificate': not_after.utc.iso8601,
                'director.abc.ca': '0',
              }.to_json

              File.open(config_file, 'w') { |f| f.write(json) }

              expected = [{
                'certificate_path' => 'director.abc.certificate',
                'expiry' => not_after.utc.iso8601,
                'days_left' => 364,
              }]

              get '/certificate_expiry'

              expect(JSON.parse(last_response.body)).to eq(expected)
            end

            it 'returns an error if the list is missing' do
              get '/certificate_expiry'

              expect(last_response.status).to eq(500)
            end

            it 'returns an error if the list is corrupt' do
              json = [].to_yaml
              File.open(config_file, 'w') { |f| f.write(json) }

              get '/certificate_expiry'

              expect(last_response.status).to eq(500)
            end
          end
        end
      end
    end
  end
end
