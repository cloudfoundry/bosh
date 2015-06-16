require 'bosh/director'

module Support
  class TestController < Bosh::Director::Api::Controllers::BaseController
    def initialize(identity_provider, requires_authentication=nil)
      super(identity_provider)
      @requires_authentication = requires_authentication
    end

    get '/test_route' do
      "Success with: #{@user || 'No user'}"
    end

    get '/read', scope: [:read] do
      "Success with: #{@user || 'No user'}"
    end

    def requires_authentication?
      @requires_authentication.nil? ? super : @requires_authentication
    end
  end
end
