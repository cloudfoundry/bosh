module Bosh::HealthMonitor

  class EmailDeliveryAgent < BaseDeliveryAgent

    DEFAULT_INTERVAL = 10

    def initialize(options = {})
      @queue = [ ]
      @lock  = Mutex.new

      @delivery_interval = options.has_key?("interval") ? options["interval"].to_f : DEFAULT_INTERVAL
      @started = false
      super
    end

    def queue_size
      @queue.size
    end

    def run
      unless EM.reactor_running?
        logger.error("Email delivery agent can only be started when event loop is running")
        return false
      end

      return true if @started

      logger.info("Email delivery agent is running...")

      EM.add_periodic_timer(@delivery_interval) do
        begin
          process_queue
        rescue => e
          logger.error("Problem processing email queue: #{e}")
        end
      end

      @started = true
    end

    def validate_options
      options.kind_of?(Hash) &&
        options["recipients"].kind_of?(Array) &&
        options["smtp"].kind_of?(Hash) &&
        options["smtp"]["host"] && options["smtp"]["port"] && options["smtp"]["from"]
    end

    def recipients
      options["recipients"]
    end

    def smtp_options
      options["smtp"]
    end

    def deliver(alert)
      @lock.synchronize do
        @queue << alert
      end
    end

    def process_queue
      return if @queue.empty?

      email_subject = "%s from Bosh Health Monitor" % [ pluralize(queue_size, "alert") ]
      email_body    = ""

      @lock.synchronize do
        while alert = @queue.shift
          email_body << formatted_alert(alert) << "\n"
        end
      end

      send_email_async(email_subject, email_body)
    end

    def formatted_alert(alert)
      result = ""
      result << "#{alert.source}\n" unless alert.source.nil?
      result << (alert.title || "Unknown Alert") << "\n"
      result << "Severity: #{alert.severity}\n"
      result << "Summary: #{alert.summary}\n" unless alert.summary.nil?
      result << "Time: #{alert.created_at.utc}\n"
    end

    def send_email_async(subject, body, date = Time.now)
      started = Time.now
      logger.debug("Sending email alert...")

      headers = {
        "From"         => smtp_options["from"],
        "To"           => recipients.join(", "),
        "Subject"      => subject,
        "Date"         => date,
        "Content-Type" => "text/plain; charset=\"iso-8859-1\""
      }

      smtp_client_options = {
        :domain   => smtp_options["domain"],
        :host     => smtp_options["host"],
        :port     => smtp_options["port"],
        :from     => smtp_options["from"],
        :to       => recipients,
        :header   => headers,
        :body     => body
      }

      if smtp_options["tls"]
        smtp_client_options[:starttls] = true
      end

      if smtp_options["auth"]
        smtp_client_options[:auth] = {
          # FIXME: EM SMTP client will only work with plain auth
          :type     => smtp_options["auth"].to_sym,
          :username => smtp_options["user"],
          :password => smtp_options["password"]
        }
      end

      email = EM::Protocols::SmtpClient.send(smtp_client_options)

      email.callback do
        logger.debug("Email alert sent (took #{Time.now - started} seconds)")
      end

      email.errback do |e|
        logger.error("Failed to send alert via email: #{e}")
      end

    rescue => e
      logger.error("Error sending email: #{e}")
    end

  end

end
