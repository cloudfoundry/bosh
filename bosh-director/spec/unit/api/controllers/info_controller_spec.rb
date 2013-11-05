require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::InfoController do
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

      describe 'Fetching status' do
        it 'not authenticated' do
          get '/info'
          last_response.status.should == 200
          Yajl::Parser.parse(last_response.body)['user'].should == nil
        end

        it 'authenticated' do
          login_as_admin
          get '/info'

          last_response.status.should == 200
          expected = {
              'name' => 'Test Director',
              'version' => "#{VERSION} (#{Config.revision})",
              'uuid' => Config.uuid,
              'user' => 'admin',
              'cpi' => 'dummy',
              'features' => {
                  'dns' => {
                      'status' => true,
                      'extras' => {'domain_name' => 'bosh'}
                  },
                  'compiled_package_cache' => {
                      'status' => true,
                      'extras' => {'provider' => 'local'}
                  },
                  'snapshots' => {
                      'status' => true
                  }
              }
          }

          Yajl::Parser.parse(last_response.body).should == expected
        end
      end
    end
  end
end
