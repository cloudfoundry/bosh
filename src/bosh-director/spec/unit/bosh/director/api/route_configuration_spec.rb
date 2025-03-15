require 'spec_helper'

module Bosh::Director
  describe Api::RouteConfiguration do
    let(:config) { Config.new({}) }
    subject(:route_configuration) { Api::RouteConfiguration.new(config) }
    before { allow(App).to receive_message_chain(:new, :blobstores, :blobstore) }

    it 'creates controllers' do
      expect { route_configuration.controllers }.not_to raise_error
    end
  end
end
