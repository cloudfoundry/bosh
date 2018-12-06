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
          context 'when queried as admin' do
            before { authorize('admin', 'admin') }

            it 'it responds with the expiry date and days left' do
              not_after = Time.now + 24 * 60 * 60 * 365
              json = {
                'director.abc.certificate': not_after.utc.iso8601,
                'director.abc.ca': '0',
              }.to_json

              config_file = Config.director_certificate_expiry_json_path
              File.open(config_file, 'w') { |f| f.write(json) }

              expected = [{
                'certificate_path' => 'director.abc.certificate',
                'expiry' => not_after.utc.iso8601,
                'days_left' => 364,
              }]

              get '/certificate_expiry'

              File.delete(config_file)
              expect(JSON.parse(last_response.body)).to eq(expected)
            end
          end

          context 'when queried as a reader' do
            before { authorize('reader', 'reader') }

            it 'it responds with the expiry date and days left' do
              not_after = Time.now + 24 * 60 * 60 * 365
              json = {
                'director.abc.certificate': not_after.utc.iso8601,
                'director.abc.ca': '0',
              }.to_json

              config_file = Config.director_certificate_expiry_json_path
              File.open(config_file, 'w') { |f| f.write(json) }

              expected = [{
                'certificate_path' => 'director.abc.certificate',
                'expiry' => not_after.utc.iso8601,
                'days_left' => 364,
              }]

              get '/certificate_expiry'

              File.delete(config_file)
              expect(JSON.parse(last_response.body)).to eq(expected)
            end

            it 'returns an error if the list is missing' do
              get '/certificate_expiry'

              expect(last_response.status).to eq(500)
            end

            it 'returns an error if the list is corrupt' do
              json = [].to_yaml
              config_file = Config.director_certificate_expiry_json_path
              File.open(config_file, 'w') { |f| f.write(json) }

              get '/certificate_expiry'

              File.delete(config_file)
              expect(last_response.status).to eq(500)
            end
          end
        end
      end

      context 'director/disks' do
        context 'when a non-authorized user asks for the disks information' do
          it 'requires auth' do
            get '/disks'
            expect(last_response.status).to eq(401)
          end
        end

        context 'when asked for for the director disk information' do
          context 'when queried as admin' do
            let(:disks_config) do
              [
                {
                  path: '/',
                  block_size: 4096,
                  blocks: 757736,
                  blocks_available: 342280,
                  blocks_free: 385173,
                },
                {
                  path: '/var/vcap/store',
                  block_size: 4096,
                  blocks: 16480703,
                  blocks_available: 15604971,
                  blocks_free: 16447902,
                },
                {
                  path: '/var/vcap/data',
                  block_size: 4096,
                  blocks: 3192100,
                  blocks_available: 2442883,
                  blocks_free: 2610793,
                },
              ]
            end

            before do
              authorize('admin', 'admin')

              disks_config.each do |c|
                disk_obj = Sys::Filesystem::Stat.new
                c.each do |k, v|
                  disk_obj.instance_variable_set("@#{k}".to_sym, v)
                end

                allow(disk_obj).to receive(:bytes_total).and_return(c[:block_size] * c[:blocks])
                allow(disk_obj).to receive(:bytes_free).and_return(c[:block_size] * c[:blocks_available])
                allow(Sys::Filesystem).to receive(:stat).with(c[:path]).and_return(disk_obj)
              end
            end

            it 'responds with the available disk space for all disks' do

              get '/disks'
              expected = [
                {
                  name:       'system',
                  size:       3103686656,
                  available:  1401978880,
                  used:       54.829,
                },
                {
                  name:       'ephemeral',
                  size:       13074841600,
                  available:  10006048768,
                  used:       23.471,
                },
                {
                  name:       'persistent',
                  size:       67504959488,
                  available:  63917961216,
                  used:       5.314,
                },
              ]

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(expected.to_json)
            end

            it 'still returns disk space for other volumes if one is unreachable' do
              allow(Sys::Filesystem).to receive(:stat).with('/var/vcap/store').and_raise(Sys::Filesystem::Error)

              get '/disks'

              expected = [
                {
                  name:       'system',
                  size:       3103686656,
                  available:  1401978880,
                  used:       54.829,
                },
                {
                  name:       'ephemeral',
                  size:       13074841600,
                  available:  10006048768,
                  used:       23.471,
                },
              ]

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(expected.to_json)
            end
          end
        end
      end
    end
  end
end
