require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResurrectionController do
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

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'resurrection' do
          it 'allows putting all job instances into different resurrection_paused values' do
            deployment = Models::Deployment.create(name: 'foo', manifest: Psych.dump('foo' => 'bar'))
            instances = [
              Models::Instance.create(deployment: deployment, job: 'dea', index: '0', state: 'started'),
              Models::Instance.create(deployment: deployment, job: 'dea', index: '1', state: 'started'),
              Models::Instance.create(deployment: deployment, job: 'dea', index: '2', state: 'started'),
            ]
            put '/resurrection', Yajl::Encoder.encode('resurrection_paused' => true), { 'CONTENT_TYPE' => 'application/json' }
            last_response.status.should == 200
            instances.each do |instance|
              expect(instance.reload.resurrection_paused).to be(true)
            end
          end
        end

      end
    end
  end
end
