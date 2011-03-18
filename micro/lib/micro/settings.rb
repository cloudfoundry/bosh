
module VCAP
  module Micro
    class Settings

      def self.secret(n)
        OpenSSL::Random.random_bytes(n).unpack("H*")[0]
      end

      # TODO: template settings file
      def self.randomize_passwords(properties)
        properties['cc']['token'] = secret(64)
        properties['cc']['password'] = secret(64)
        properties['nats']['password'] = secret(8)
        properties['ccdb']['password'] = secret(8)
        properties['mysql_node']['password'] = properties['ccdb']['password']
        properties
      end

    end
  end
end
