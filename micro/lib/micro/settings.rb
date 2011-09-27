
module VCAP
  module Micro
    class Settings

      def self.preserve(properties, service, key)
        properties[service] && properties[service][key]
      end

      def self.secret(n)
        OpenSSL::Random.random_bytes(n).unpack("H*")[0]
      end

      def self.randomize_password(properties, service, key, len)
        properties[service] = {} unless properties[service]
        unless preserve(properties, service, key)
          properties[service][key] = secret(len)
        end
      end

      # TODO: template settings file
      def self.randomize_passwords(properties)
        randomize_password(properties, 'cc', 'token', 64)
        randomize_password(properties, 'cc', 'password', 64)
        randomize_password(properties, 'router', 'password', 8)
        router = properties['router']
        randomize_password(router, 'status', 'user', 8)
        randomize_password(router, 'status', 'password', 8)
        randomize_password(properties, 'nats', 'password', 8)
        randomize_password(properties, 'ccdb', 'password', 8)
        randomize_password(properties, 'mysql_node', 'password', 8)
        randomize_password(properties, 'mysql_gateway', 'token', 4)
        randomize_password(properties, 'redis_gateway', 'token', 4)
        randomize_password(properties, 'mongodb_gateway', 'token', 4)

        randomize_password(properties, 'postgresql_gateway', 'admin_passwd_hash', 4)
        randomize_password(properties, 'postgresql_gateway', 'token', 8)

        properties['postgresql_node']['admin_passwd_hash'] = properties['postgresql_gateway']['admin_passwd_hash']

        randomize_password(properties, 'rabbitmq_srs', 'admin_passwd_hash', 4)
        randomize_password(properties, 'rabbitmq_srs', 'token', 64)
        randomize_password(properties, 'rabbitmq_srs', 'backbone_password', 4)

        properties
      end

    end
  end
end
