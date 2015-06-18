require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResurrectionController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
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
      let(:config) { Config.load_hash(test_config) }
      before { basic_authorize 'admin', 'admin' }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      describe 'API calls' do
        describe 'resurrection' do
          it 'allows putting all job instances into different resurrection_paused values' do
            deployment = Models::Deployment.create(name: 'foo', manifest: Psych.dump('foo' => 'bar'))
            instances = [
              Models::Instance.create(deployment: deployment, job: 'dea', index: '0', state: 'started'),
              Models::Instance.create(deployment: deployment, job: 'dea', index: '1', state: 'started'),
              Models::Instance.create(deployment: deployment, job: 'dea', index: '2', state: 'started'),
            ]
            put '/', Yajl::Encoder.encode('resurrection_paused' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            instances.each do |instance|
              expect(instance.reload.resurrection_paused).to be(true)
            end
          end
        end

      end
    end
  end
end
