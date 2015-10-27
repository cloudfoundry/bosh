require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::CleanupController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }

      let(:temp_dir) { Dir.mktmpdir }
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

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      after { FileUtils.rm_rf(temp_dir) }

      context 'when request body asks to delete orphaned disks' do
        it 'cleans up all orphaned disks' do
          post('/', JSON.generate('config' => {'remove_all' => true}), {'CONTENT_TYPE' => 'application/json'})

          expect_redirect_to_queued_task(last_response)
        end
      end
    end
  end
end
