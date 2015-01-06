require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResourcesController do
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
        described_class.new
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
        expect(last_response.status).to eq(404)
      end

      context 'when serving resources from temp' do
        let(:resouce_manager) { instance_double('Bosh::Director::Api::ResourceManager') }
        let(:tmp_file) { File.join(Dir.tmpdir, "resource-#{SecureRandom.uuid}") }

        def app
          allow(ResourceManager).to receive(:new).and_return(resouce_manager)
          described_class.new
        end

        before do
          File.open(tmp_file, 'w') do |f|
            f.write('some data')
          end

          FileUtils.touch(tmp_file)
        end

        it 'cleans up temp file after serving it' do
          login_as_admin
          expect(resouce_manager).to receive(:get_resource_path).with('deadbeef').and_return(tmp_file)

          expect(File.exists?(tmp_file)).to be(true)
          get '/deadbeef'
          expect(last_response.body).to eq('some data')
          expect(File.exists?(tmp_file)).to be(false)
        end
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'resources' do
          it '404 on missing resource' do
            get '/missing_resource'
            expect(last_response.status).to eq(404)
          end

          it 'can fetch resources from blobstore' do
            id = @director_app.blobstores.blobstore.create('some data')
            get "/#{id}"
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('some data')
          end
        end
      end
    end
  end
end
