require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::StemcellsController do
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

        describe 'creating a stemcell' do
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

        describe 'listing stemcells' do
          it 'has API call that returns a list of stemcells in JSON' do
            stemcells = (1..10).map do |i|
              Models::Stemcell.
                  create(:name => "stemcell-#{i}", :version => i,
                         :cid => rand(25000 * i))
            end

            get '/stemcells', {}, {}
            last_response.status.should == 200

            body = Yajl::Parser.parse(last_response.body)

            body.kind_of?(Array).should be(true)
            body.size.should == 10

            response_collection = body.map do |e|
              [e['name'], e['version'], e['cid']]
            end

            expected_collection = stemcells.sort_by { |e| e.name }.map do |e|
              [e.name.to_s, e.version.to_s, e.cid.to_s]
            end

            response_collection.should == expected_collection
          end

          it 'returns empty collection if there are no stemcells' do
            get '/stemcells', {}, {}
            last_response.status.should == 200

            body = Yajl::Parser.parse(last_response.body)
            body.should == []
          end
        end
      end
    end
  end
end
