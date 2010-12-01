require "json"

module Bosh
  module Cli

    class User

      def self.create(api_client, username, password)
        payload = JSON.generate("username" => username, "password" => password)
        status, body = api_client.post("/users", "application/json", payload)

        created = status == 200

        message = \
        if created
          "User #{username} has been created"
        elsif status == 401
          "Error 401: Authentication failed"
        elsif status == 500
          begin
            decoded_body = JSON.parse(body.to_s)
            "Director error %s: %s" % [ decoded_body["code"], decoded_body["description"] ]
          rescue JSON::ParserError
            "Director error: #{body}"
          end
        else
          "Director response: #{status} #{body}"
        end

        [ created, message ]
      end
      
    end
    
  end
end
