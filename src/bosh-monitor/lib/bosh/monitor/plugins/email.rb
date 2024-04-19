require 'net/smtp'

module Bosh::Monitor
  module Plugins
    class Email < Base
      DEFAULT_INTERVAL = 10

      def initialize(options = {})
        @queues = {}
        @lock = Mutex.new

        @delivery_interval = if options.key?('interval')
                               options['interval'].to_f
                             else
                               DEFAULT_INTERVAL
                             end

        @started = false
        super
      end

      def queue_size(kind)
        return 0 if @queues[kind].nil?

        @queues[kind].size
      end

      def run
        unless ::Async::Task.current?
          logger.error('Email plugin can only be started when event loop is running')
          return false
        end

        return true if @started

        logger.info('Email plugin is running...')

        Async do |task|
          loop do
            process_queues
            sleep(@delivery_interval)
          rescue StandardError => e
            logger.error("Problem processing email queues: #{e}")
          end
        end
        @started = true
      end

      def validate_options
        options.is_a?(Hash) &&
          options['recipients'].is_a?(Array) &&
          options['smtp'].is_a?(Hash) &&
          options['smtp']['host'] &&
          options['smtp']['port'] &&
          options['smtp']['from'] &&
          true # force the whole method to return Boolean
      end

      def recipients
        options['recipients']
      end

      def smtp_options
        options['smtp']
      end

      def process(event)
        @lock.synchronize do
          @queues[event.kind] ||= []
          @queues[event.kind] << event
        end
      end

      def process_queues
        logger.info('Proccessing queues...')
        @queues.each_pair do |kind, queue|
          next if queue.empty?

          logger.info('Creating email...')
          email_subject = "#{pluralize(queue_size(kind), kind)} from BOSH Health Monitor"
          email_body = ''

          @lock.synchronize do
            while (event = queue.shift)
              logger.info('Dequeueing...')
              email_body << event.to_plain_text << "\n"
            end
          end

          send_email_async(email_subject, email_body)
        end
      end

      def send_email_async(subject, body, date = Time.now)
        started = Time.now
        logger.info('Sending email...')

        headers = create_headers(subject, date)

        smtp_start_params = [smtp_options['domain']]
        if smtp_options['auth']
          smtp_start_params += [smtp_options['user'], smtp_options['password'], smtp_options['auth'].to_sym]
        end

        Async do
          starttls_mode = smtp_options['tls'] ? :always : false
          smtp = Net::SMTP.new(smtp_options['host'], smtp_options['port'], starttls: starttls_mode)
          smtp.start(*smtp_start_params) do |smtp|
            smtp.send_message(formatted_message(headers, body), smtp_options['from'], recipients)
            logger.debug("Email sent (took #{Time.now - started} seconds)")
          end
        rescue Net::SMTPError => e
          logger.error("Failed to send email: #{e}")
        rescue StandardError => e
          logger.error("Error sending email: #{e}")
        end
      end

      def create_headers(subject, date)
        {
          'From' => smtp_options['from'],
          'To' => recipients.join(', '),
          'Subject' => subject,
          'Date' => date.strftime('%a, %-d %b %Y %T %z'),
          'Content-Type' => 'text/plain; charset="iso-8859-1"',
        }
      end

      def formatted_message(headers_hash, body_text)
        headers_text = headers_hash.map { |key, value| "#{key}: #{value}" }.join("\r\n")

        "#{headers_text}\r\n\r\n#{body_text}"
      end
    end
  end
end
