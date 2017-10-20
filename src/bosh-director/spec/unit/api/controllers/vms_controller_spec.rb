require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::VmsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      it 'deletes a vm' do
        delete '/vm-cid-1'
        expect_redirect_to_queued_task(last_response)
      end
    end
  end
end
