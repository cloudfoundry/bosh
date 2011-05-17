module Bosh::HealthMonitor

  class EmailAlertProcessor < BaseAlertProcessor
    # TODO: this blocks event loop while sending, consider EM::defer or EM::SmtpClient
    # Note that EM::defer has problems with 1.9 (as seen in DEA)

    def validate_options
      options["recipients"].is_a?(Array) && options["smtp"].is_a?(Hash) &&
        options["smtp"]["host"] && options["smtp"]["port"]
    end

    def process(raw_alert)
      smtp_options = options["smtp"]

      headers = {
        "From"         => smtp_options["from"],
        "To"           => options["recipients"].join(", "),
        "Subject"      => "BOSH Health Monitor Alert",
        "Date"         => Time.now,
        "Content-Type" => "text/plain; charset=\"iso-8859-1\""
      }

      body        = raw_alert
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

      options["recipients"].each do |recipient|
        smtp.send_message(message, smtp_options["from"], recipient)
      end

      smtp.finish

    rescue => e
      logger.error("Cannot send an email: #{e}")
    end

  end

end
