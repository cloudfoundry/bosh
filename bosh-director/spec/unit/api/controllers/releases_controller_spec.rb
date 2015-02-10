require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ReleasesController do
      include Rack::Test::Methods

      let!(:temp_dir) { Dir.mktmpdir}

      before do
        blobstore_dir = File.join(temp_dir, 'blobstore')
        FileUtils.mkdir_p(blobstore_dir)

        test_config = Psych.load(spec_asset('test-director-config.yml'))
        test_config['dir'] = temp_dir
        test_config['blobstore'] = {
            'provider' => 'local',
            'options' => {'blobstore_path' => blobstore_dir}
        }
        test_config['snapshots']['enabled'] = true
        Config.configure(test_config)
        @director_app = App.new(Config.load_hash(test_config))
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      def app
        @rack_app ||= described_class.new
      end

      def login_as_admin
        basic_authorize 'admin', 'admin'
      end

      def login_as(username, password)
        basic_authorize username, password
      end

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

      describe 'GET', '/' do
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

      describe 'DELETE', '/<id>' do
        before { authorize 'admin', 'admin' }

        it 'deletes the whole release' do
          release = Models::Release.create(:name => 'test_release')
          release.add_version(Models::ReleaseVersion.make(:version => '1'))
          release.save

          delete '/test_release'
          expect_redirect_to_queued_task(last_response)
        end

        it 'deletes a particular version' do
          release = Models::Release.create(:name => 'test_release')
          release.add_version(Models::ReleaseVersion.make(:version => '1'))
          release.save

          delete '/test_release?version=1'
          expect_redirect_to_queued_task(last_response)
        end
      end

      describe 'GET', '<id>' do
        before { authorize 'admin', 'admin' }
        
        it 'returns versions' do
          release = Models::Release.create(:name => 'test_release')
          (1..10).map do |i|
            release.add_version(Models::ReleaseVersion.make(:version => i))
          end
          release.save

          get '/test_release'
          expect(last_response.status).to eq(200)
          body = Yajl::Parser.parse(last_response.body)

          expect(body['versions'].sort).to eq((1..10).map { |i| i.to_s }.sort)
        end
      end
    end
  end
end
