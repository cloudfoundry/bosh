module Bosh::Monitor
  class ApiController < Sinatra::Base
    PULSE_TIMEOUT = 180

    def initialize(heartbeat_interval = 1)
      @heartbeat = Time.now
      @instance_manager = Bosh::Monitor.instance_manager

      Async do |task|
        loop do
          @heartbeat = Time.now
          sleep(heartbeat_interval)
        end
      end

      super
    end

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    get '/healthz' do
      body "Last pulse was #{Time.now - @heartbeat} seconds ago"

      if Time.now - @heartbeat > PULSE_TIMEOUT
        logger.error('PULSE TIMEOUT REACHED: queued jobs are not processing in a timely fashion')
        status(500)
      else
        status(200)
      end
    end

    get '/unresponsive_agents' do
      if @instance_manager.director_initial_deployment_sync_done
        JSON.generate(@instance_manager.unresponsive_agents)
      else
        status(503)
      end
    end

    get "/unhealthy_agents" do
      if @instance_manager.director_initial_deployment_sync_done
        JSON.generate(@instance_manager.unhealthy_agents)
      else
        status(503)
      end
    end
  end
end
