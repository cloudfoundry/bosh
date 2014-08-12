module Bat
  class BoshApi
    def initialize(hostname, logger)
      @logger = logger
      @director_url = "https://#{hostname}:25555"
    end

    def info
      http_get('/info')
    end

    # @return [Array[String]]
    def deployments
      result = {}
      http_get('/deployments').each { |d| result[d['name']] = d }
      result
    end

    def releases
      result = []
      http_get('/releases').each do |r|
        result << Bat::Release.new(r['name'], r['release_versions'].map { |v| v['version'] })
      end
      result
    end

    def stemcells
      result = []
      http_get('/stemcells').each do |s|
        result << Bat::Stemcell.new(s['name'], s['version'])
      end
      result
    end

    private

    def http_get(path)
      response = http_client.get([@director_url, path].join, 'application/json')
      if response.status != 200
        raise "Director request failed to '#{path}' with status #{response.status}:\nBODY:\n#{response.body}"
      end
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "Failed to parse director response to '#{path}':\nBODY:\n#{response.body}\nERROR: #{e}"
    end

    def http_client
      @http_client ||= HTTPClient.new.tap do |c|
        c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        c.set_auth(@director_url, 'admin', 'admin')
      end
    end
  end
end
