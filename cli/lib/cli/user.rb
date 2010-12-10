require "json"

module Bosh
  module Cli

    class User

      def self.create(api_client, username, password)
        payload = JSON.generate("username" => username, "password" => password)
        status, body = api_client.post("/users", "application/json", payload)
        status == 200
      end
      
    end
    
  end
end
