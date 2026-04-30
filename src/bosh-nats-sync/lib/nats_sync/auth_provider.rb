require 'uaa'

module NATSSync
  class AuthProvider
    def initialize(auth_info, config, logger)
      @auth_info = auth_info.fetch('user_authentication', {})

      @user = config['user'].to_s
      @password = config['password'].to_s
      @client_id = config['client_id'].to_s
      @client_secret = config['client_secret'].to_s
      @director_ca_cert = config['director_ca_cert'].to_s
      @uaa_ca_cert = config['uaa_ca_cert'].to_s
      @uaa_public_key = config['uaa_public_key'].to_s

      @logger = logger
    end

    def auth_header
      if @auth_info.fetch('type', 'local') == 'uaa'
        uaa_url = @auth_info.fetch('options', {}).fetch('url')
        return uaa_token_header(uaa_url)
      end

      "Basic #{Base64.encode64("#{@user}:#{@password}").strip}"
    end

    private

    def uaa_token_header(uaa_url)
      @uaa_token ||= UAAToken.new(@client_id, @client_secret, uaa_url, ca_file_path, @uaa_public_key, @logger)
      @uaa_token.auth_header
    end

    def ca_file_path
      uaa = @uaa_ca_cert.to_s
      if !uaa.empty? && File.exist?(uaa) && !File.read(uaa).strip.empty?
        uaa
      else
        @director_ca_cert.to_s
      end
    end
  end

  class UAAToken
    EXPIRATION_DEADLINE_IN_SECONDS = 60

    def initialize(client_id, client_secret, uaa_url, ca_cert_file_path, uaa_public_key, logger)
      options = {}

      if File.exist?(ca_cert_file_path) && !File.read(ca_cert_file_path).strip.empty?
        options[:ssl_ca_file] = ca_cert_file_path
      else
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        options[:ssl_cert_store] = cert_store
      end

      @uaa_token_issuer = CF::UAA::TokenIssuer.new(
        uaa_url,
        client_id,
        client_secret,
        options,
      )
      @uaa_public_key = uaa_public_key.to_s
      @logger = logger
    end

    def auth_header
      return @uaa_token.auth_header if @uaa_token && !expires_soon?

      fetch

      @uaa_token ? @uaa_token.auth_header : nil
    end

    private

    def expires_soon?
      expiration = @token_data[:exp] || @token_data['exp']
      (Time.at(expiration).to_i - Time.now.to_i) < EXPIRATION_DEADLINE_IN_SECONDS
    end

    def fetch
      token = @uaa_token_issuer.client_credentials_grant
      token_data = decode_token(token)
      @uaa_token = token
      @token_data = token_data
    rescue StandardError => e
      @logger.error("Failed to obtain or decode token from UAA: #{e.inspect}")
      @uaa_token = nil
      @token_data = nil
    end

    def decode_token(token)
      access_token = token.info['access_token'] || token.info[:access_token]
      CF::UAA::TokenCoder.decode(access_token, decode_options)
    end

    def decode_options
      if @uaa_public_key.strip.empty?
        { verify: false }
      else
        { pkey: @uaa_public_key, verify: true }
      end
    end
  end
end
