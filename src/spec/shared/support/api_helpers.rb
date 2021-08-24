module Support
  module ApiHelpers
    def send_director_post_request(url_path, query, request_body, auth = {username: 'test', password: 'test'}, init_header = {'Content-Type' =>'application/json'})
      director_url = build_director_api_url(url_path, query)

      req = Net::HTTP::Post.new(director_url, init_header)
      req.body = request_body
      req.basic_auth(auth[:username], auth[:password]) unless auth.empty?
      send_director_api_request(director_url, req)
    end

    def send_director_get_request(url_path, query, auth = {username: 'test', password: 'test'})
      director_url = build_director_api_url(url_path, query)

      req = Net::HTTP::Get.new(director_url)
      req.basic_auth(auth[:username], auth[:password]) unless auth.empty?

      send_director_api_request(director_url, req)
    end

    def send_director_delete_request(url_path, query, auth = {username: 'test', password: 'test'})
      director_url = build_director_api_url(url_path, query)

      req = Net::HTTP::Delete.new(director_url)
      req.basic_auth(auth[:username], auth[:password]) unless auth.empty?

      send_director_api_request(director_url, req)
    end

    def send_director_api_request(director_url, request)
      Net::HTTP.start(
        director_url.hostname,
        director_url.port,
        :use_ssl => true,
        :verify_mode => OpenSSL::SSL::VERIFY_PEER,
        :ca_file => current_sandbox.certificate_path) {|http|
        http.request(request)
      }
    end

    def build_director_api_url(url_path, query)
      director_url = URI(current_sandbox.director_url)
      director_url.path = url_path
      director_url.query = query
      return director_url
    end
  end
end

RSpec.configure do |config|
  config.include(Support::ApiHelpers)
end
