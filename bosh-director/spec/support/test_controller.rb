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

    get '/exceptional' do
      raise Bosh::Director::DirectorError,  <<ERROR
jUgKUxonotx7pxy7me9Gyhmtaouyj82nLTqnC64OE0QF
1UZSl8qAgUfv78sAYusbblIEbNstJAj9ep7K3JLc9XRl
37KmtvsN2tAB3CxHkFmz4Y52kcMb7Uh1XZkU7k2ceUlB
paweywrDGsFJEqKcbJC64k1YcuOlCQ9xaaut4l3GRuwn
WwIS8DJqvMUozlatAi0oxmEXsVT1ArkNkkoVu9fKGPTx
Cl6QwxATzMlGlLbfqJB0ofqh8QkUQyJnk9iN6e27MFif
V1P5m4lGsmsUCfyrnEAcOaACh0rG2CauXJcEjCCeGkpl
2YqQWpbW9165ZqE7bPw9fNCG4J1PRv6taqQ3RYjAxXvF
LDPSnF49Hu6kKlVzAr7WFmuuZR4RIGHKPSSQ0pEmqh8U
xm0FrDxPzhRuV5pO81hogV940rPUnpvR4MIgqOwEnFpi
pTYXHkLjbkmnWXozxwYp1qJt5OHZ0nsMvZen206FlSx1
g2KctieN0DZkgZVixKAg6TQgZngkzVSYYvwmrV8qxh7g
36riEaWVe91ZW0Kggpo2yoS1VpBHauwlD0tgBHbP2CzM
Xg1HT1W5W1KZPKMAV5jtaXyiBwJ8
ERROR
    end

    def requires_authentication?
      @requires_authentication.nil? ? super : @requires_authentication
    end
  end
end
