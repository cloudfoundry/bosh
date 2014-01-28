module Bat
  class Env
    VARS = {
      director:             'BAT_DIRECTOR',
      stemcell_path:        'BAT_STEMCELL',
      deployment_spec_path: 'BAT_DEPLOYMENT_SPEC',
      vcap_password:        'BAT_VCAP_PASSWORD',
      dns_host:             'BAT_DNS_HOST',
    }.freeze

    def self.from_env
      new(Hash[VARS.map { |k, v| [k, ENV[v]] }])
    end

    attr_reader(*VARS.keys)

    def initialize(vars)
      VARS.keys.each do |name|
        val = vars[name]
        raise ArgumentError, "Missing #{name}" unless val
        instance_variable_set("@#{name}", val)
      end
    end
  end
end
