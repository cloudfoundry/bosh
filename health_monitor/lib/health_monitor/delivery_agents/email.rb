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

      send_email(email_subject, email_body)
    end

    def formatted_alert(alert)
      result = ""
      result << (alert.title || "Unknown Alert") << "\n"
      result << "Severity: #{alert.severity}\n"
      result << "Summary: #{alert.summary}\n"
      result << "Time: #{alert.created_at.utc}\n"
    end

    # TODO: this blocks event loop while sending, consider EM::defer or EM::SmtpClient
    # Note that EM::defer has problems with 1.9 (as seen in DEA)
    def send_email(subject, body, date = Time.now)
      started = Time.now
      logger.debug("Sending email alert...")

      headers = {
        "From"         => smtp_options["from"],
        "To"           => recipients.join(", "),
        "Subject"      => subject,
        "Date"         => date,
        "Content-Type" => "text/plain; charset=\"iso-8859-1\""
      }

      headers_str = headers.map { |(k, v)| "#{k}: #{v}"}.join("\r\n")
      message     = "#{headers_str}\r\n\r\n#{body}"
      smtp        = Net::SMTP.new(smtp_options["host"], smtp_options["port"])

      # We use 1.9 so we're fine but 1.8 would require plugin to enable TLS with net/smtp
      smtp.enable_starttls

      if smtp_options["auth"]
        smtp.start(smtp_options["domain"], smtp_options["user"], smtp_options["password"], smtp_options["auth"])
      else
        smtp.start(smtp_options["domain"])
      end

      recipients.each do |recipient|
        smtp.send_message(message, smtp_options["from"], recipient)
      end

      smtp.finish

      logger.debug("Email alert sent (took #{Time.now - started} seconds)")

    rescue => e
      logger.error("Cannot send an email: #{e}")
    end

  end

end
