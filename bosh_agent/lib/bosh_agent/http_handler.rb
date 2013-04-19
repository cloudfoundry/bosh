# Copyright (c) 2009-2012 VMware, Inc.

require "thin"
require "sinatra"
require "monitor"
require "common/ssl"

module Bosh::Agent

  class HTTPHandler < Handler

    def self.start
      new.start
    end

    def start
      handler = self

      uri = URI.parse(Config.mbus)

      @server = Thin::Server.new(uri.host, uri.port) do
        use Rack::CommonLogger

        if uri.userinfo
          use Rack::Auth::Basic do |user, password|
            "#{user}:#{password}" == uri.userinfo
          end
        end

        map "/" do
          run AgentController.new(handler)
        end
      end

      certificate = Bosh::Ssl::Certificate.new('agent.key',
                                               'agent.cert',
                                               uri.host
      ).load_or_create

      @server.ssl = true
      @server.ssl_options = {:ssl_verify => false, :ssl_key_file => certificate.key_path, :ssl_cert_file => certificate.certificate_path }

      @server.start!
    end

    def shutdown
      @logger.info("Exit")
      @server.stop
    end

    def handle_message(json)
      result = {}
      result.extend(MonitorMixin)

      cond = result.new_cond
      timeout_time = Time.now.to_f + 30

      @callback = Proc.new do |response|
        result.synchronize do
          result.merge!(response)
          cond.signal
        end
      end

      super(json)

      result.synchronize do
        while result.empty?
          timeout = timeout_time - Time.now.to_f
          unless timeout > 0
            raise "Timed out"
          end
          cond.wait(timeout)
        end
      end

      result
    end

    def publish(reply_to, payload, &blk)
      response = @callback.call(payload)
      blk.call if blk
      response
    end
  end

  module Message
    class ReleaseApplySpec < Base

      def self.process(args)
        self.new.apply_spec
      end

      def release_apply_spec
        #generated from bosh-release and baked into the stemcell
        "/var/vcap/micro/apply_spec.yml"
      end

      def apply_spec
        Psych.load_file(release_apply_spec)
      end
    end
  end

  class AgentController < Sinatra::Base

    def initialize(handler)
      super()
      @handler = handler
    end

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    post "/agent" do
      body = request.env["rack.input"].read
      response = handle_message(body)
      content_type(:json)
      response
    end

    def handle_message(json)
      begin
        payload = @handler.handle_message(json)
      rescue => e
        payload = RemoteException.from(e).to_hash
      end

      Yajl::Encoder.encode(payload, :terminator => "\n")
    end
  end
end
