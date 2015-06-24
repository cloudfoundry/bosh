require 'bosh/director'

module Support
  class TestController < Bosh::Director::Api::Controllers::BaseController
    def initialize(config, requires_authentication=nil)
      super(config)
      @requires_authentication = requires_authentication
    end

    get '/test_route' do
      "Success with: #{current_user || 'No user'}"
    end

    get '/read', scope: :read do
      "Success with: #{current_user || 'No user'}"
    end

    get '/params', scope: Bosh::Director::Api::Extensions::Scoping::ParamsScope.new(:name, {test: :read}) do
      "Success with: #{current_user || 'No user'}"
    end

    def requires_authentication?
      @requires_authentication.nil? ? super : @requires_authentication
    end
  end
end
