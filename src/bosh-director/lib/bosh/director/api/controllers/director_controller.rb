module Bosh::Director
  module Api::Controllers
    class DirectorController < BaseController
      get '/certificate_expiry', scope: :read do
        # puts 'current path =' + `pwd`
        content_type(:json)

        begin
          contents = File.read(Config.director_certificate_expiry_json_path)
          certificates = JSON.parse(contents)
        rescue Errno::ENOENT, JSON::ParserError => e
          status(500)
          return json_encode('error' => "Certificate expiry information not available: #{e.inspect}")
        end

        cert_expiration_info = []
        certificates.each do |k, v|
          next if v == '0'

          not_after = Time.iso8601(v)
          days_left = ((not_after - Time.now) / 60 / 60 / 24).floor
          cert_expiration_info << {
            certificate_path: k,
            expiry: v,
            days_left: days_left,
          }
        end
        json_encode(cert_expiration_info)
      end
    end
  end
end
