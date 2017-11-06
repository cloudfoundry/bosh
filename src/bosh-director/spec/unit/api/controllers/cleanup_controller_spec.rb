require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::CleanupController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when request body asks to delete orphaned disks' do
        it 'cleans up all orphaned disks' do
          post('/', JSON.generate('config' => {'remove_all' => true}), {'CONTENT_TYPE' => 'application/json'})

          expect_redirect_to_queued_task(last_response)
        end
      end
    end
  end
end
