require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::Controllers::StemcellsController do
    include Rack::Test::Methods

    subject(:app) { linted_rack_app(described_class.new(config)) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    before { App.new(config) }

    describe 'POST', '/' do
      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'allows json body with remote stemcell location' do
          post '/', JSON.generate('location' => 'http://stemcell_url'), { 'CONTENT_TYPE' => 'application/json' }
          expect_redirect_to_queued_task(last_response)
        end

        it 'allow form parameters with a stemcell local file path' do
          allow(File).to receive(:exists?).with('/path/to/stemcell.tgz').and_return(true)

          post '/', { 'nginx_upload_path' => '/path/to/stemcell.tgz'}, { 'CONTENT_TYPE' => 'multipart/form-data' }
          expect_redirect_to_queued_task(last_response)
        end

        context 'when a sha1 is provided' do
          it 'allows json body with remote stemcell location and sha1' do
            post '/', JSON.generate({'location' => 'http://stemcell_url', 'sha1' => 'shawone'}), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'allow form parameters with a stemcell local file path and sha1' do
            allow(File).to receive(:exists?).with('/path/to/stemcell.tgz').and_return(true)

            post '/', { 'nginx_upload_path' => '/path/to/stemcell.tgz', 'sha1' => 'shawone'}, { 'CONTENT_TYPE' => 'multipart/form-data' }
            expect_redirect_to_queued_task(last_response)
          end
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

      context 'team admin access' do
        before { authorize 'dev-team-member', 'dev-team-member' }

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

              body = JSON.parse(last_response.body)
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

              body = JSON.parse(last_response.body)
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
            expect(JSON.parse(last_response.body)).to eq([])
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

      context 'team admin access' do
        before { authorize 'dev-team-member', 'dev-team-member' }
        let(:stemcells) { [] }

        it 'returns stemcells if any' do
          perform
          expect(last_response.status).to eq(200)
        end
      end
    end
  end
end
