require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::Controllers::StemcellsController do
    include Rack::Test::Methods

    subject(:app) { described_class.new(config) }
    let(:config) { Config.load_hash(test_config) }
    let(:temp_dir) { Dir.mktmpdir}
    let(:test_config) do
      config = Psych.load(spec_asset('test-director-config.yml'))
      config['dir'] = temp_dir
      config['blobstore'] = {
        'provider' => 'local',
        'options' => {'blobstore_path' => File.join(temp_dir, 'blobstore')}
      }
      config
    end

    before { App.new(config) }

    after { FileUtils.rm_rf(temp_dir) }

    describe 'POST', '/' do
      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'allows json body with remote stemcell location' do
          post '/', Yajl::Encoder.encode('location' => 'http://stemcell_url'), { 'CONTENT_TYPE' => 'application/json' }
          expect_redirect_to_queued_task(last_response)
        end

        it 'allow form parameters with a stemcell local file path' do
          allow(File).to receive(:exists?).with('/path/to/stemcell.tgz').and_return(true)

          post '/', { 'nginx_upload_path' => '/path/to/stemcell.tgz'}, { 'CONTENT_TYPE' => 'multipart/form-data' }
          expect_redirect_to_queued_task(last_response)
        end

        it 'only consumes application/json and multipart/form-data' do
          post '/', 'fake-data', { 'CONTENT_TYPE' => 'application/octet-stream' }
          expect(last_response.status).to eq(404)
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/', '', { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          post '/', '', { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'GET', '/stemcells' do
      def perform
        get '/', {}, {}
      end

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        context 'when there are some stemcells' do
          let(:stemcells) do
            (1..10).map do |i|
              Models::Stemcell.create(
                :name => "stemcell-#{i}",
                :version => i,
                :cid => rand(25000 * i),
              )
            end
          end

          context 'when deployments use stemcells' do
            before { stemcells.each { |s| s.add_deployment(deployment); s.save } }
            let(:deployment) { Models::Deployment.create(:name => 'fake-deployment-name') }

            it 'returns a list of stemcells in JSON with existing deployments' do
              perform
              expect(last_response.status).to eq(200)

              body = Yajl::Parser.parse(last_response.body)
              expect(body).to be_an_instance_of(Array)
              expect(body.size).to eq(10)

              response_collection = body.map do |e|
                [e['name'], e['version'], e['cid'], e['deployments']]
              end

              expected_collection = stemcells.sort_by(&:name).map do |e|
                [e.name.to_s, e.version.to_s, e.cid.to_s, [{ 'name' => 'fake-deployment-name' }]]
              end

              expect(response_collection).to eq(expected_collection)
            end
          end

          context 'when deployments use stemcells' do
            before { stemcells.each { |s| allow(s).to receive(:deployments).and_return([]) } }

            it 'returns a list of stemcells in JSON with no existing deployments' do
              perform
              expect(last_response.status).to eq(200)

              body = Yajl::Parser.parse(last_response.body)
              expect(body).to be_an_instance_of(Array)
              expect(body.size).to eq(10)

              response_collection = body.map do |e|
                [e['name'], e['version'], e['cid'], e['deployments']]
              end

              expected_collection = stemcells.sort_by(&:name).map do |e|
                [e.name.to_s, e.version.to_s, e.cid.to_s, []]
              end

              expect(response_collection).to eq(expected_collection)
            end
          end
        end

        context 'when there are no stemcells' do
          let(:stemcells) { [] }

          it 'returns empty collection if there are no stemcells' do
            perform
            expect(last_response.status).to eq(200)
            expect(Yajl::Parser.parse(last_response.body)).to eq([])
          end
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'scope' do
      let(:identity_provider) { Support::TestIdentityProvider.new }
      let(:config) do
        config = Config.load_hash(test_config)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      it 'accepts read scope for routes allowing read access' do
        authorize 'admin', 'admin'

        get '/'
        expect(identity_provider.scope).to eq(:read)

        non_read_routes = [
          [:post, '/', 'Content-Type', 'application/json'],
          [:post, '/', 'Content-Type', 'application/multipart'],
          [:delete, '/stemcell-name/stemcell-version', '', '']
        ]

        non_read_routes.each do |method, route, header, header_value|
          header header, header_value
          method(method).call(route, '{}')
          expect(identity_provider.scope).to eq(:write)
        end
      end
    end
  end
end
