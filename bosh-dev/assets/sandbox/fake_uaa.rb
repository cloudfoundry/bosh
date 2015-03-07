require 'sinatra/base'
require 'thin'
require 'sinatra/namespace'
# rubocop:disable LineLength

fake_uaa_app = Sinatra.new do
  register Sinatra::Namespace

  namespace '/uaa' do
    get '/login' do
      content_type :json
      '{"app":{"version":"2.0.3"},"createAccountLink":"/create_account","forgotPasswordLink":"/forgot_password","links":{"uaa":"http://localhost:8080/uaa","passwd":"/forgot_password","login":"http://localhost:8080/login","loginPost":"http://localhost:8080/uaa/login.do","register":"/create_account"},"entityID":"cloudfoundry-saml-login","commit_id":"620cac2","prompts":{"username":["text","Email"],"password":["password","Password"],"passcode":["password","One Time Code (Get one at http://localhost:8080/uaa/passcode)"]},"idpDefinitions":[],"timestamp":"2015-02-05T15:16:38-0800"}'
    end

    get /(.*)/ do |path|
      puts "Unhandled UAA request to #{path}"
    end
  end
end

fake_uaa_app.set :logging, true
fake_uaa_app.set :port, ENV['PORT']
fake_uaa_app.set :ssl, true
fake_uaa_app.set :raise_errors, true

fake_uaa_app.start! do |server|
  server.ssl = true
  server.ssl_options = {
    :verify_peer => false
  }
end

# rubocop:enable LineLength
