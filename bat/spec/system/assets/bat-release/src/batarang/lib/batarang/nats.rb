# Copyright (c) 2009-2012 VMware, Inc.

class Batarang::NATS
  include Singleton

  SLEEP = 1

  def initialize
    @state = :uninitialized
  end

  def start(index)
    NATS.on_error { |error| on_error(error) }
    @nats = NATS.connect(:autostart => false) { on_connect(index) }
    EM.add_periodic_timer(5) { @nats.publish("bat.#{index}", ip) }
  rescue Errno::ENETUNREACH, NATS::ConnectError => e
    @state = :failed
    # log
    puts("failed to connect: #{e.message}")
    sleep(SLEEP)
    retry
  end

  def on_error(error)
    puts("error: #{error}")
    @state = :error
  end

  def on_connect(index)
    @state = :running
    @nats.subscribe("bat.#{index}") do |json|
      handler(json)
    end
  end

  def running?
    @state == :running
  end

  def state
    @state.to_s
  end

  def handler(message)
    json = JSON::parse(message)
    puts "json = #{json}"
  rescue JSON::JSONError => e
    # log error
    puts("handler error: #{e.inspect}")
  end

  def ip
    ifconfig = %x{ifconfig eth0 2> /dev/null}
    match = ifconfig.match(/addr:(\d+\.\d+\.\d+\.\d+)/)
    if match
      match[1]
    else
      "ip-missing"
    end
  end
end
