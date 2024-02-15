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
        unless EventMachine.reactor_running?
          logger.error('Email plugin can only be started when event loop is running')
          return false
        end

        return true if @started

        logger.info('Email plugin is running...')

        EventMachine.add_periodic_timer(@delivery_interval) do
          process_queues
        rescue StandardError => e
          logger.error("Problem processing email queues: #{e}")
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
            while event = queue.shift
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

        smtp_client_options = {
          domain: smtp_options['domain'],
          host: smtp_options['host'],
          port: smtp_options['port'],
          from: smtp_options['from'],
          to: recipients,
          header: headers,
          body: body,
        }

        smtp_client_options[:starttls] = true if smtp_options['tls']

        if smtp_options['auth']
          smtp_client_options[:auth] = {
            # FIXME: EventMachine SMTP client will only work with plain auth
            type: smtp_options['auth'].to_sym,
            username: smtp_options['user'],
            password: smtp_options['password'],
          }
        end

        email = EventMachine::Protocols::SmtpClient.send(smtp_client_options)

        email.callback do
          logger.debug("Email sent (took #{Time.now - started} seconds)")
        end

        email.errback do |e|
          logger.error("Failed to send email: #{e}")
        end
      rescue StandardError => e
        logger.error("Error sending email: #{e}")
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
    end
  end
end
