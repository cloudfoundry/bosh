
module VCAP
  module Micro
    class Settings

      def self.secret(n)
        OpenSSL::Random.random_bytes(n).unpack("H*")[0]
      end

      # TODO: template settings file

    end
  end
end
