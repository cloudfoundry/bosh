require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ReleasesController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      before { App.new(config) }

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
            post '/', JSON.generate('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
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

          context 'sha1s' do
            context 'sha1 is provided as both a query param and a body content' do
              it 'returns an error' do
                post '/?sha1=0xABAD1DEA', JSON.generate('location' => 'http://release_url', 'sha1' => '0xABAD1DEA'), { 'CONTENT_TYPE' => 'application/json' }
                expect(last_response.status).to eq(400)
              end
            end
          end
        end

        context 'when user has readonly permissions' do
          context 'when user has readonly access' do
            before { authorize 'reader', 'reader' }

            it 'returns 401' do
              post '/', JSON.generate('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(401)
            end
          end
        end

        context 'when user has team admin permission' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          it 'returns 401' do
            post '/', JSON.generate('location' => 'http://release_url'), { 'CONTENT_TYPE' => 'application/json' }
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

            expect(body).to eq(JSON.generate(expected_collection))
          end

          it 'returns empty collection if there are no releases' do
            get '/', {}, {}
            expect(last_response.status).to eq(200)

            body = JSON.parse(last_response.body)
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
        let(:params) do
          {
            release_name: 'release-name-value',
            release_version: 'release-version-value',
            stemcell_os:    'bosh-stemcell-os-value',
            stemcell_version:    'bosh-stemcell-version-value',
          }
        end

        def perform
          post '/export', JSON.dump(params), { 'CONTENT_TYPE' => 'application/json' }
        end

        context 'when the request does NOT contains the sha2 flag' do
          before { authorize 'admin', 'admin' }

          it 'authenticated access redirect to the created task' do
            expected_sha2_param = nil
            expected_params = [nil, 'release-name-value', 'release-version-value', 'bosh-stemcell-os-value', 'bosh-stemcell-version-value', expected_sha2_param, {:jobs => nil}]
            expect(Jobs::DBJob).to receive(:new).with(Jobs::ExportRelease, 1, expected_params).and_return(Jobs::DBJob.new(Jobs::ExportRelease, 1, expected_params))
            perform
          end
        end

        context 'when the request contains the sha2 flag' do
          let(:params) do
            {
              release_name:        'release-name-value',
              release_version:     'release-version-value',
              stemcell_os:         'bosh-stemcell-os-value',
              stemcell_version:    'bosh-stemcell-version-value',
              sha2:                 'true'
            }
          end

          before { authorize 'admin', 'admin' }

          it 'authenticated access redirect to the created task' do
            expected_sha2_param = 'true'
            expected_params = [nil, 'release-name-value', 'release-version-value', 'bosh-stemcell-os-value', 'bosh-stemcell-version-value', expected_sha2_param, {:jobs => nil}]
            expect(Jobs::DBJob).to receive(:new).with(Jobs::ExportRelease, 1, expected_params).and_return(Jobs::DBJob.new(Jobs::ExportRelease, 1, expected_params))
            perform
          end
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

        context 'when user specifies jobs' do
          let(:params) do
            {
              release_name: 'release-name-value',
              release_version: 'release-version-value',
              stemcell_os:    'bosh-stemcell-os-value',
              stemcell_version:    'bosh-stemcell-version-value',
              jobs: [
                {name: 'foo'},
                {name: 'bar'},
              ],
            }
          end

          before { authorize 'admin', 'admin' }
          it 'creates export-release task with jobs param populated' do
            mock_release_manager = instance_double('Bosh::Director::Api::ReleaseManager')
            allow(ReleaseManager).to receive(:new).and_return(mock_release_manager)

            expected_options = {
              :jobs => [
                {'name' => 'foo'},
                {'name' => 'bar'},
              ]
            }

            expected_params = [nil, params[:release_name], params[:release_version], params[:stemcell_os], params[:stemcell_version], nil, expected_options]
            expect(Jobs::DBJob).to receive(:new).with(Jobs::ExportRelease, 1, expected_params).and_return(Jobs::DBJob.new(Jobs::ExportRelease, 1, expected_params))
            perform
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
            body = JSON.parse(last_response.body)

            expect(body['versions'].sort).to eq((1..10).map { |i| i.to_s }.sort)
          end

          it 'satisfies inspect release calls' do
            release_version = Models::ReleaseVersion.find(:version => '1')

            dummy_template = Models::Template.make(
              release_id: 1,
              name: 'dummy_template',
              version: '2',
              blobstore_id: '123',
              sha1: '12a',
              spec: {
                consumes: {'link-consumed' => 'consumed'},
                provides: {'link-provided' => 'provided'},
              },
            )

            release_version.add_template(dummy_template)

            get '/test_release?version=1'
            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)

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
