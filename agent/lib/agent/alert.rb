module Bosh::Agent
  class Alert

    ALERT_RETRIES    = 3
    RETRY_PERIOD     = 1 # second
    SEVERITY_CUTOFF  = 5
    DEFAULT_SEVERITY = 2

    # The main area of responsibility for this class is conversion
    # of Monit alert format to Bosh Health Monitor alert format.

    attr_reader :id, :service, :event, :description, :action, :date, :severity

    def self.register(attrs)
      new(attrs).register
    end

    def initialize(attrs)
      unless attrs.is_a?(Hash)
        raise ArgumentError, "#{self.class} expects an attributes Hash as a parameter"
      end

      @logger   = Config.logger
      @nats     = Config.nats
      @agent_id = Config.agent_id

      @id          = attrs[:id]
      @service     = attrs[:service]
      @event       = attrs[:event]
      @action      = attrs[:action]
      @date        = attrs[:date]
      @description = attrs[:description]
      @severity    = self.calculate_severity
    end

    # As we don't (currently) require ACKs for alerts we might need to
    # send alerts several times in case HM temporarily goes down
    def register
      return if severity >= SEVERITY_CUTOFF
      ALERT_RETRIES.times do |i|
        EM.add_timer(i * RETRY_PERIOD) do
          send_via_mbus
        end
      end
    end

    def send_via_mbus
      @nats.publish("hm.agent.alert.#{@agent_id}", Yajl::Encoder.encode(converted_alert_data))
    end

    def converted_alert_data
      # INPUT: id, service, event, action, date, description
      # OUTPUT: id, severity, title, summary, created_at (unix timestamp)
      {
        "id"         => @id,
        "severity"   => self.calculate_severity,
        "title"      => "#{@service} - #{@event} - #{@action}",
        "summary"    => @description,
        "created_at" => self.timestamp
      }
    end

    def timestamp
      Time.rfc822(@date).utc.to_i
    rescue ArgumentError => e
      @logger.warn("Cannot parse monit alert date `#{@date}', using current time instead")
      Time.now.utc.to_i
    end

    def calculate_severity
      known_severity = SEVERITY_MAP[@event.to_s.downcase]
      if known_severity.nil?
        @logger.warn("Unknown monit event name `#{@event}', using default severity #{DEFAULT_SEVERITY}")
        DEFAULT_SEVERITY
      else
        known_severity
      end
    end

    SEVERITY_MAP = {
      "action done"                  => 5,
      "checksum failed"              => 2,
      "checksum changed"             => 4,
      "checksum succeeded"           => 5,
      "checksum not changed"         => 5,
      "connection failed"            => 1,
      "connection succeeded"         => 5,
      "connection changed"           => 3,
      "connection not changed"       => 5,
      "content failed"               => 3,
      "content succeeded"            => 5,
      "content match"                => 5,
      "content doesn't match"        => 3,
      "data access error"            => 3,
      "data access succeeded"        => 5,
      "data access changed"          => 4,
      "data access not changed"      => 5,
      "execution failed"             => 1,
      "execution succeeded"          => 5,
      "execution changed"            => 4,
      "execution not changed"        => 5,
      "filesystem flags failed"      => 3,
      "filesystem flags succeeded"   => 5,
      "filesystem flags changed"     => 4,
      "filesystem flags not changed" => 5,
      "gid failed"                   => 3,
      "gid succeeded"                => 5,
      "gid changed"                  => 4,
      "gid not changed"              => 5,
      "heartbeat failed"             => 3,
      "heartbeat succeeded"          => 5,
      "heartbeat changed"            => 4,
      "heartbeat not changed"        => 5,
      "icmp failed"                  => 2,
      "icmp succeeded"               => 5,
      "icmp changed"                 => 4,
      "icmp not changed"             => 5,
      "monit instance failed"        => 1,
      "monit instance succeeded"     => 5,
      "monit instance changed"       => 4,
      "monit instance not changed"   => 5,
      "invalid type"                 => 3,
      "type succeeded"               => 5,
      "type changed"                 => 4,
      "type not changed"             => 5,
      "does not exist"               => 1,
      "exists"                       => 5,
      "existence changed"            => 4,
      "existence not changed"        => 5,
      "permission failed"            => 3,
      "permission succeeded"         => 5,
      "permission changed"           => 4,
      "permission not changed"       => 5,
      "pid failed"                   => 2,
      "pid succeeded"                => 5,
      "pid changed"                  => 4,
      "pid not changed"              => 5,
      "ppid failed"                  => 2,
      "ppid succeeded"               => 5,
      "ppid changed"                 => 4,
      "ppid not changed"             => 5,
      "resource limit matched"       => 3,
      "resource limit succeeded"     => 5,
      "resource limit changed"       => 4,
      "resource limit not changed"   => 5,
      "size failed"                  => 3,
      "size succeeded"               => 5,
      "size changed"                 => 3,
      "size not changed"             => 5,
      "timeout"                      => 2,
      "timeout recovery"             => 5,
      "timeout changed"              => 4,
      "timeout not changed"          => 5,
      "timestamp failed"             => 3,
      "timestamp succeeded"          => 5,
      "timestamp changed"            => 4,
      "timestamp not changed"        => 5,
      "uid failed"                   => 2,
      "uid succeeded"                => 5,
      "uid changed"                  => 4,
      "uid not changed"              => 5
    }
  end
end
