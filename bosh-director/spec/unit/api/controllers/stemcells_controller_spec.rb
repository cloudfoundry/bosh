require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::Controllers::StemcellsController do
    include Rack::Test::Methods

    subject(:app) { described_class } # "app" is a Rack::Test hook

    let!(:temp_dir) { Dir.mktmpdir}

    before do
      config = Psych.load(spec_asset('test-director-config.yml'))
      config['dir'] = temp_dir
      config['blobstore'] = {
        'provider' => 'local',
        'options' => {'blobstore_path' => File.join(temp_dir, 'blobstore')}
      }
      App.new(Config.load_hash(config))
    end

    after { FileUtils.rm_rf(temp_dir) }

    describe 'POST', '/stemcells' do
      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'expects compressed stemcell file' do
          post '/stemcells', spec_asset('tarball.tgz'), { 'CONTENT_TYPE' => 'application/x-compressed' }
          expect_redirect_to_queued_task(last_response)
        end

        it 'expects remote stemcell location' do
          post '/stemcells', Yajl::Encoder.encode('location' => 'http://stemcell_url'), { 'CONTENT_TYPE' => 'application/json' }
          expect_redirect_to_queued_task(last_response)
        end

        it 'only consumes application/x-compressed and application/json' do
          post '/stemcells', spec_asset('tarball.tgz'), { 'CONTENT_TYPE' => 'application/octet-stream' }
          last_response.status.should == 404
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/stemcells'
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          post '/stemcells'
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'GET', '/stemcells' do
      def perform
        get '/stemcells', {}, {}
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
            before { stemcells.each { |s| s.stub(:deployments).and_return([]) } }

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
  end
end
