module Bosh::Deployer
  class Specification

    def self.load_from_stemcell(dir)
      spec = load_apply_spec(dir)
      Specification.new(spec)
    end

    def self.load_apply_spec(dir)
      file = "apply_spec.yml"
      apply_spec = File.join(dir, file)
      unless File.exist?(apply_spec)
        err "this isn't a micro bosh stemcell - #{file} missing"
      end
      Psych.load_file(apply_spec)
    end

    attr_accessor :spec
    attr_accessor :properties

    def initialize(spec)
      @spec = spec
      @properties = @spec["properties"]
    end

    # Update the spec with the IP of the micro bosh instance.
    # @param [String] bosh_ip IP address of the micro bosh VM
    # @param [String] service_ip private IP of the micro bosh VM on AWS/OS,
    #   or the same as the bosh_ip if vSphere/vCloud
    def update(bosh_ip, service_ip)
      # set the director name to what is specified in the micro_bosh.yml
      if Config.name
        @properties["director"] = {} unless @properties["director"]
        @properties["director"]["name"] = Config.name
      end

      # on AWS blobstore and nats need to use an elastic IP (if available),
      # as when the micro bosh instance is re-created during a deployment,
      # it might get a new private IP
      %w{blobstore nats}.each do |service|
        update_agent_service_address(service, bosh_ip)
      end

      services = %w{director redis blobstore nats registry dns}
      services.each do |service|
        update_service_address(service, service_ip)
      end

      # health monitor does not listen to any ports, so there is no
      # need to update the service address, but we still want to
      # be able to override values in the apply_spec
      override_property(@properties, "hm", Config.spec_properties["hm"])

      override_property(@properties, "director", Config.spec_properties["director"])
      set_property(@properties, "ntp", Config.spec_properties["ntp"])
      set_property(@properties, "compiled_package_cache", Config.spec_properties["compiled_package_cache"])

      @spec
    end

    # @param [String] name property name to delete from the spec
    def delete(name)
      @spec.delete(name)
    end

    # @return [String] the port the director runs on
    def director_port
      @properties["director"]["port"]
    end

    private

    # update the agent service section from the contents of the apply_spec
    def update_agent_service_address(service, address)
      agent = @properties["agent"] ||= {}
      svc = agent[service] ||= {}
      svc["address"] = address

      override_property(agent, service, Config.agent_properties[service])
    end

    def update_service_address(service, address)
      return unless @properties[service]
      @properties[service]["address"] = address

      override_property(@properties, service, Config.spec_properties[service])
    end

    def set_property(properties, key, value)
      properties[key] = value unless value.nil?
    end

    def override_property(properties, service, override)
      properties[service].merge!(override) if override
    end
  end
end
