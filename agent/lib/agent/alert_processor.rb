module Bosh::Agent

  # AlertProcessor is a simple SMTP server + callback for processing alerts.
  # It is primarily meant to be used with Monit.

  class AlertProcessor
    class Error < StandardError; end

    def self.start(host, port, user, password)
      processor = new(host, port, user, password)
      processor.start
      processor
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

      @server = EM.start_server(@host, @port, Bosh::Agent::SmtpServer, :user => @smtp_user, :password => @smtp_password, :processor => self)
      @logger.info "Now accepting SMTP connections on address #{@host}, port #{@port}"
    end

    def stop
      if @server
        if EM.reactor_running?
          EM.stop_server(@server)
          @logger.info "Stopped alert processor"
        end
        @server = nil
      end
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
    #   Description: $DESCRIPTION
    #   }

    # == Returns:
    # true if succeeded to process the alert, false if failed
    #
    def process_email_alert(raw_email)
      create_alert_from_email(raw_email).register
    end

    def create_alert_from_email(raw_email)
      @logger.debug "Received email alert: #{raw_email}"

      attrs = { }

      raw_email.split(/\r?\n/).each do |line|
        case line
        when /^\s*Message-id:\s*<(.*)>$/i
          attrs[:id] = $1.split("@")[0] # Remove host
        when /^\s*Service:\s*(.*)$/i
          attrs[:service] = $1
        when /^\s*Event:\s*(.*)$/i
          attrs[:event] = $1
        when /^\s*Action:\s*(.*)$/i
          attrs[:action] = $1
        when /^\s*Date:\s*(.*)$/i
          attrs[:date] = $1
        when /^\s*Description:\s*(.*)$/i
          attrs[:description] = $1
        end
      end

      @logger.debug("Extracted email alert data: #{attrs}")
      Alert.new(attrs)
    end

  end

end
