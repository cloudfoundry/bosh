module Bosh::Monitor
  class ApiController < Sinatra::Base
    PULSE_TIMEOUT = 180

    def initialize
      @heartbeat = Time.now
      @instance_manager = Bosh::Monitor.instance_manager

      EventMachine.add_periodic_timer(1) do
        EventMachine.defer { @heartbeat = Time.now }
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
        logger.error('PULSE TIMEOUT REACHED: Eventmachine not processing queued jobs in a timely fashion')
        status(500)
      else
        status(200)
      end
    end

    get '/unresponsive_agents' do
      JSON.generate(@instance_manager.unresponsive_agents)
    end
  end
end
