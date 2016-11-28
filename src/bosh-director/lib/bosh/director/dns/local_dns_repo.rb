module Bosh::Director
  class LocalDnsRepo

    def initialize(logger)
      @logger = logger
    end

    def find(instance_model)
      instance_model.dns_record_names.to_a
    end

    def create_or_update(instance_model, dns_record_names)
      instance_model.update(dns_record_names: dns_record_names)
    end

    def delete(instance_model)
      instance_model.update(dns_record_names: [])
    end
  end
end
