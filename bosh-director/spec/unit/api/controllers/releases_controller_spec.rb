require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ReleasesController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(test_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end
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

      before { App.new(config) }

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
        expect(last_response.status).to eq(200)
      end

      describe 'POST', '/' do
        context 'when user has admin access' do

          before { authorize 'admin', 'admin' }
          it 'allows json body with remote release location' do
            post '/', Yajl::Encoder.encode('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'allow form parameters with a release local file path' do
            allow(File).to receive(:exists?).with('/path/to/release.tgz').and_return(true)

            post '/', { 'nginx_upload_path' => '/path/to/release.tgz'}, { 'CONTENT_TYPE' => 'multipart/form-data' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'only consumes application/json and multipart/form-data' do
            post '/', 'fake-data', { 'CONTENT_TYPE' => 'application/octet-stream' }
            expect(last_response.status).to eq(404)
          end
        end

        context 'when user has readonly permissions' do
          context 'when user has readonly access' do
            before { authorize 'reader', 'reader' }

            it 'returns 401' do
              post '/', Yajl::Encoder.encode('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(401)
            end
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns 401' do
            post '/', Yajl::Encoder.encode('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(401)
          end
        end
      end

      describe 'GET', '/' do
        context 'when user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'has API call that returns a list of releases in JSON' do
            release1 = Models::Release.create(name: 'release-1')
            Models::ReleaseVersion.
                create(release: release1, version: 1)
            deployment1 = Models::Deployment.create(name: 'deployment-1')
            release1 = deployment1.add_release_version(release1.versions.first) # release-1 is now currently_deployed
            release2 = Models::Release.create(name: 'release-2')
            Models::ReleaseVersion.
                create(release: release2, version: 2, commit_hash: '0b2c3d', uncommitted_changes: true)

            get '/', {}, {}
            expect(last_response.status).to eq(200)
            body = last_response.body

            expected_collection = [
                {'name' => 'release-1',
                 'release_versions' => [Hash['version', '1', 'commit_hash', 'unknown', 'uncommitted_changes', false, 'currently_deployed', true, 'job_names', []]]},
                {'name' => 'release-2',
                 'release_versions' => [Hash['version', '2', 'commit_hash', '0b2c3d', 'uncommitted_changes', true, 'currently_deployed', false, 'job_names', []]]}
            ]

            expect(body).to eq(Yajl::Encoder.encode(expected_collection))
          end

          it 'returns empty collection if there are no releases' do
            get '/', {}, {}
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body).to eq([])
          end
        end

        context 'when user has readonly permissions' do
          context 'when user has readonly access' do
            before { authorize 'reader', 'reader' }

            it 'returns versions' do
              get '/'
              expect(last_response.status).to eq(200)
            end
          end

          context 'when user is not authorized' do
            it 'returns 401' do
              get '/'
              expect(last_response.status).to eq(401)
            end
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns versions' do
            get '/'
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'POST', '/export' do
        def perform
          params = {
            release_name: 'release-name-value',
            release_version: 'release-version-value',
            stemcell_os:    'bosh-stemcell-os-value',
            stemcell_version:    'bosh-stemcell-version-value',
          }
          post '/export', JSON.dump(params), { 'CONTENT_TYPE' => 'application/json' }
        end

        context 'when user has admin access' do
          before { authorize 'admin', 'admin' }

          it 'authenticated access redirect to the created task' do
            perform
            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'when user has readonly permissions' do
          context 'when user has readonly access' do
            before { authorize 'reader', 'reader' }

            it 'returns 401' do
              perform
              expect(last_response.status).to eq(401)
            end
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns versions' do
            perform
            expect(last_response.status).to eq(401)
          end
        end
      end

      describe 'DELETE', '/<id>' do
        before do
          release = Models::Release.create(:name => 'test_release')
          release.add_version(Models::ReleaseVersion.make(:version => '1'))
          release.save
        end

        context 'when user has admin access' do
          before { authorize 'admin', 'admin' }

          it 'deletes the whole release' do
            delete '/test_release'
            expect_redirect_to_queued_task(last_response)
          end

          it 'deletes a particular version' do
            delete '/test_release?version=1'
            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'when user has readonly permissions' do
          context 'when user has readonly access' do
            before { authorize 'reader', 'reader' }

            it 'returns 401' do
              delete '/test_release?version=1'
              expect(last_response.status).to eq(401)
            end
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns 401' do
            delete '/test_release?version=1'
            expect(last_response.status).to eq(401)
          end
        end
      end

      describe 'GET', '<id>' do
        let!(:release) do
          release = Models::Release.create(:name => 'test_release')
          (1..10).map do |i|
            release.add_version(Models::ReleaseVersion.make(:version => i))
          end
          release.save
        end

        context 'when user has admin access' do
          before { authorize 'admin', 'admin' }

          it 'returns versions' do
            get '/test_release'
            expect(last_response.status).to eq(200)
            body = Yajl::Parser.parse(last_response.body)

            expect(body['versions'].sort).to eq((1..10).map { |i| i.to_s }.sort)
          end

          it 'satisfies inspect release calls' do
            release_version = Models::ReleaseVersion.find(:version => 1)

            dummy_template = Models::Template.make(
                :release_id => 1,
                :name => 'dummy_template',
                :version => '2',
                :blobstore_id => '123',
                :sha1 => '12a',
                :consumes => 'link-consumed',
                :provides => 'link-provided',
            )

            release_version.add_template(dummy_template)

            get '/test_release?version=1'
            expect(last_response.status).to eq(200)
            body = Yajl::Parser.parse(last_response.body)

            dummy_template_result = body['jobs'][0]
            expect(dummy_template_result['name']).to eq('dummy_template')
            expect(dummy_template_result['blobstore_id']).to eq('123')
            expect(dummy_template_result['sha1']).to eq('12a')
            expect(dummy_template_result['consumes']).not_to be_nil
            expect(dummy_template_result['provides']).not_to be_nil
          end
        end

        context 'when user has readonly access' do
          before { authorize 'reader', 'reader' }

          it 'returns versions' do
            get '/test_release'
            expect(last_response.status).to eq(200)
          end
        end

        context 'when user is not authorized' do
          it 'returns 401' do
            get '/test_release'
            expect(last_response.status).to eq(401)
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns versions' do
            get '/test_release'
            expect(last_response.status).to eq(200)
          end
        end
      end
    end
  end
end
