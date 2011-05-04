module Bosh::Agent

  class AlertProcessor
    class Error < StandardError; end

    def self.start(host, port, user, password)
      new(host, port, user, password).start
    end

    def initialize(host, port, smtp_user, smtp_password)
      @host          = host
      @port          = port
      @smtp_user     = smtp_user
      @smtp_password = smtp_password
      @logger        = Config.logger
    end

    def start
      unless EM.reactor_running?
        raise Error, "Cannot start SMTP server as event loop is not running"
      end

      EM.start_server(@host, @port, Bosh::Agent::SmtpServer, :user => @smtp_user, :password => @smtp_password, :processor => self)
      @logger.info "Now accepting SMTP connections on address #{@host}, port #{@port}"
    end

    # Processes raw alert received by email (i.e. from Monit).
    #
    # == Parameters:
    # raw_email::
    #   A String containg raw alert data. In Monit case it is essentially
    #   a raw email text (incl. headers). We only accept the following
    #   Monit alert format:
    #   set mail-format {
    #     from: monit@localhost
    #     subject: Monit Alert
    #     message: Service: $SERVICE
    #   Event: $EVENT
    #   Action: $ACTION
    #   Date: $DATE
    #   }

    # == Returns:
    # true if succeeded to process the alert, false if failed
    #
    def process_email_alert(raw_email)
      @logger.debug "Received email alert: #{raw_email}"

      alert_id = nil
      service  = nil
      event    = nil
      action   = nil
      date     = nil

      raw_email.split(/\r?\n/).each do |line|
        case line
        when /^\s*Message-id:\s*<(.*)>$/i
          alert_id = $1.split("@")[0] # Remove host
        when /^\s*Service:\s*(.*)$/i
          service = $1
        when /^\s*Event:\s*(.*)$/i
          event = $1
        when /^\s*Action:\s*(.*)$/i
          action = $1
        when /^\s*Date:\s*(.*)$/i
          date = $1
        end
      end

      @logger.info("Extracted email alert data: id=#{alert_id}, service=#{service}, event=#{event}, action=#{action}, date=#{date}")
      Alert.register(alert_id, service, event, action, date)

      true
    end

  end

end
