
module VCAP
  module Micro
    class Settings

      def self.secret(n)
        OpenSSL::Random.random_bytes(n).unpack("H*")[0]
      end

      def self.set_prop(properties, service, key, len)
        properties[service] = {} unless properties[service]
        properties[service][key] = secret(len)
      end

      # TODO: template settings file
      def self.randomize_passwords(properties)
        set_prop(properties, 'cc', 'token', 64)
        set_prop(properties, 'cc', 'password', 64)
        set_prop(properties, 'router', 'password', 8)
        router = properties['router']
        set_prop(router, 'status', 'user', 8)
        set_prop(router, 'status', 'password', 8)
        set_prop(properties, 'nats', 'password', 8)
        set_prop(properties, 'ccdb', 'password', 8)
        set_prop(properties, 'mysql_node', 'password', 8)
        set_prop(properties, 'mysql_gateway', 'token', 4)
        set_prop(properties, 'redis_gateway', 'token', 4)
        set_prop(properties, 'mongodb_gateway', 'token', 4)
        set_prop(properties, 'postgresql_node', 'admin_passwd_hash', 4)
        set_prop(properties, 'postgresql_gateway', 'admin_passwd_hash', 4)
        set_prop(properties, 'postgresql_gateway', 'token', 8)
        set_prop(properties, 'rabbitmq_srs', 'backbone_password', 4)
        set_prop(properties, 'rabbitmq_srs', 'admin_passwd_hash', 4)
        set_prop(properties, 'rabbitmq_srs', 'token', 8)
        properties
      end

    end
  end
end
