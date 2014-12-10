module Bosh::Monitor
  class ApiController < Sinatra::Base
    PULSE_TIMEOUT = 180

    def initialize
      @heartbeat = Time.now

      EM.add_periodic_timer(1) do
        EM.defer { @heartbeat = Time.now }
      end

      super
    end

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    helpers do
      def protected!
        return if authorized?
        headers['WWW-Authenticate'] = ''
        halt 401, 'Unauthorized'
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [Bhm.http_user, Bhm.http_password]
      end
    end

    get "/varz" do
      protected!
      content_type(:json)
      Yajl::Encoder.encode(Bhm.varz, :terminator => "\n")
    end

    get "/healthz" do
      body "Last pulse was #{Time.now - @heartbeat} seconds ago"

      if Time.now - @heartbeat > PULSE_TIMEOUT
        status(500)
      else
        status(200)
      end
    end
  end
end
