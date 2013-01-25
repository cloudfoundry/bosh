# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  # TODO: payload max size should be enforced via underlying LineText2 protocol
  # but it seems to be missing there, potentially need to monkeypatch LineText2
  # to add it.
  class SmtpServer < EM::Protocols::SmtpServer

    class Error < StandardError; end

    MAX_MESSAGE_SIZE   = 1024 * 1024 # 1M
    INACTIVITY_TIMEOUT = 10 # seconds

    def initialize(*args)
      super

      options = args.last

      @logger        = Config.logger
      @user          = options[:user]
      @password      = options[:password]
      @processor     = options[:processor]
      @authenticated = false
      @chunks        = [ ]
      @msg_size      = 0

      # @parms come from EM:Protocols::SmtpServer
      @parms[:auth] = true if @user && @password

      self.comm_inactivity_timeout = INACTIVITY_TIMEOUT
    end

    def get_server_greeting
      "BOSH Agent SMTP Server"
    end

    def get_server_domain
      get_server_greeting
    end

    def authenticated?
      @authenticated
    end

    # We don't really care about senders and recipients
    # as we only use SMTP for data transport between
    # Monit and Agent. However it's handy to use
    # the SMTP sequence constraints to enforce that
    # only authenticated user can actually send data.

    def receive_plain_auth(user, password)
      @authenticated = (user == @user && @password == password)
    end

    # Only accept MAIL FROM if already authenticated
    def receive_sender(sender)
      authenticated?
    end

    # Only accept RCPT TO if already authenticated
    def receive_recipient(rcpt)
      authenticated?
    end

    def receive_data_chunk(c)
      @msg_size += c.join.length

      if @msg_size > MAX_MESSAGE_SIZE
        send_data "552 Message too large\r\n"
        close_connection_after_writing
      else
        @chunks += c
      end
    end

    def receive_message
      unless @processor
        @logger.error "Failed to process alert: no alert processor provided"
        return false
      end

      unless @processor.respond_to?(:process_email_alert)
        @logger.error "Failed to process alert: alert processor should respond to :process_email_alert method"
        return false
      end

      message = @chunks.join("\n")
      @chunks = [ ] # Support multiple data blocks in a single SMTP session
      @processor.process_email_alert(message)

      # WARNING: this MUST return true, otherwise Monit will try to send alerts over and over again
      true
    end

  end

end

