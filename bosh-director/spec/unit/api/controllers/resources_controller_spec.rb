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
        @rack_app ||= Controller.new
      end

      def login_as_admin
        basic_authorize 'admin', 'admin'
      end

      def login_as(username, password)
        basic_authorize username, password
      end

      it 'requires auth' do
        get '/'
        last_response.status.should == 401
      end

      it 'sets the date header' do
        get '/'
        last_response.headers['Date'].should_not be_nil
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
             "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        last_response.status.should == 404
      end

      context 'when serving resources from temp' do
        let(:resouce_manager) { instance_double('Bosh::Director::Api::ResourceManager') }
        let(:tmp_file) { File.join(Dir.tmpdir, "resource-#{SecureRandom.uuid}") }

        def app
          ResourceManager.stub(new: resouce_manager)
          Controller.new
        end

        before do
          File.open(tmp_file, 'w') do |f|
            f.write('some data')
          end

          FileUtils.touch(tmp_file)
        end

        it 'cleans up temp file after serving it' do
          login_as_admin

          resouce_manager.should_receive(:get_resource_path).with('deadbeef').and_return(tmp_file)

          File.exists?(tmp_file).should be(true)
          get '/resources/deadbeef'
          last_response.body.should == 'some data'
          File.exists?(tmp_file).should be(false)
        end
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'resources' do
          it '404 on missing resource' do
            get '/resources/deadbeef'
            last_response.status.should == 404
          end

          it 'can fetch resources from blobstore' do
            id = @director_app.blobstores.blobstore.create('some data')
            get "/resources/#{id}"
            last_response.status.should == 200
            last_response.body.should == 'some data'
          end
        end
      end
    end
  end
end
