require 'bosh/dev'

module Bosh::Dev::Bat
  class DirectorAddress
    def self.from_env(env, env_key)
      new(env[env_key], env[env_key])
    end

    def self.resolved_from_env(env, env_key)
      hostname = "micro.#{env[env_key]}.cf-app.com"
      new(hostname, Resolv.getaddress(hostname))
    end

    attr_reader :hostname, :ip

    def initialize(hostname, ip)
      @hostname = hostname
      @ip = ip
    end
  end
end
