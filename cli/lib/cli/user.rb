module Bosh
  module Cli

    class User

      def self.create(api_client, username, password)
        payload = Yajl::Encoder.encode("username" => username, "password" => password)        
        status, body = api_client.request(:post, "/users", payload, "application/json")

        created = status == 200

        message = \
        if created
          "User #{username} has been created"
        elsif status == 401
          "Error 401: Authentication failed"
        else
          decoded_body = Yajl::Parser.parse(body.to_s)
          "Error %s: %s" % [ decoded_body["code"], decoded_body["description"] ]
        end

        [ created, message ]
      end
      
    end
    
  end
end
