module Support
  module ApiHelpers
    def send_director_api_request(url_path, query, method, auth = {username: 'test', password: 'test'})
      director_url = URI(current_sandbox.director_url)
      director_url.path = URI.escape(url_path)
      director_url.query = URI.escape(query)

      req = Net::HTTP::Get.new(director_url)

      req.basic_auth(auth[:username], auth[:password]) unless auth.empty?

      Net::HTTP.start(
        director_url.hostname,
        director_url.port,
        :use_ssl => true,
        :verify_mode => OpenSSL::SSL::VERIFY_PEER,
        :ca_file => current_sandbox.certificate_path) {|http|
        http.request(req)
      }
    end
  end
end

RSpec.configure do |config|
  config.include(Support::ApiHelpers)
end