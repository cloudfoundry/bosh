module Bosh::Deployer
  class Specification
    def self.load_from_stemcell(dir, config)
      spec = load_apply_spec(dir)
      Specification.new(spec, config)
    end

    def self.load_apply_spec(dir)
      file = 'apply_spec.yml'
      apply_spec = File.join(dir, file)
      err "this isn't a micro bosh stemcell - #{file} missing" unless File.exist?(apply_spec)
      Psych.load_file(apply_spec)
    end

    attr_accessor :spec
    attr_accessor :properties

    def initialize(spec, config)
      @config = config
      @spec = spec
      @properties = @spec['properties']
    end

    # Update the spec with the IP of the micro bosh instance.
    # @param [String] agent_services_ip IP address of the micro bosh VM
    # @param [String] internal_services_ip private IP of the micro bosh VM
    def update(agent_services_ip, internal_services_ip)
      # set the director name to what is specified in the micro_bosh.yml
      if config.name
        @properties['director'] = {} unless @properties['director']
        @properties['director']['name'] = config.name
      end

      %w{blobstore nats}.each do |service|
        update_agent_service_address(service, agent_services_ip)
        update_service_address(service, internal_services_ip)
      end

      %w{registry dns}.each do |service|
        update_service_address(service, agent_services_ip)
      end

      update_service_address('director', internal_services_ip)

      update_properties

      @spec
    end

    # @param [String] name property name to delete from the spec
    def delete(name)
      @spec.delete(name)
    end

    # @return [String] the port the director runs on
    def director_port
      @properties['director']['port']
    end

    private

    attr_reader :config

    # health monitor does not listen to any ports, so there is no
    # need to update the service address, but we still want to
    # be able to override values in the apply_spec
    def update_properties
      override_property(@properties, 'hm', config.spec_properties['hm'])
      override_property(@properties, 'director', config.spec_properties['director'])
      set_property(@properties, 'ntp', config.spec_properties['ntp'])

      set_property(
        @properties,
        'compiled_package_cache',
        config.spec_properties['compiled_package_cache'],
      )
    end

    # update the agent service section from the contents of the apply_spec
    def update_agent_service_address(service, address)
      agent = @properties['agent'] ||= {}
      svc = agent[service] ||= {}
      svc['address'] = address

      override_property(agent, service, config.agent_properties[service])
    end

    def update_service_address(service, address)
      return unless @properties[service]
      @properties[service]['address'] = address

      override_property(@properties, service, config.spec_properties[service])
    end

    def set_property(properties, key, value)
      properties[key] = value unless value.nil?
    end

    def override_property(properties, service, override)
      properties[service].merge!(override) if override
    end
  end
end
