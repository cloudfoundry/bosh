module Bosh::Monitor
  class Instance
    attr_reader :id, :agent_id, :job, :index, :cid, :expects_vm, :job_state, :has_processes
    attr_accessor :deployment, :job_state

    def initialize(instance_data)
      @logger = Bosh::Monitor.logger
      @id     = instance_data['id']
      @agent_id = instance_data['agent_id']
      @job = instance_data['job']
      @index = instance_data['index']
      @cid = instance_data['cid']
      @expects_vm = instance_data['expects_vm']
      @job_state = instance_data['job_state']
      @has_processes = instance_data['has_processes']
    end

    def self.create(instance_data)
      unless instance_data.is_a?(Hash)
        Bosh::Monitor.logger.error("Invalid format for Instance data: expected Hash, got #{instance_data.class}: #{instance_data}")
        return nil
      end

      unless instance_data['id']
        Bosh::Monitor.logger.error("Instance data has no id: got #{instance_data}")
        return nil
      end

      Instance.new(instance_data)
    end

    def name
      if @job
        identifier = "#{@job}(#{@id})"
        attributes = create_optional_attributes(%i[agent_id index job_state has_processes])
        attributes += create_mandatory_attributes([:cid])
      else
        identifier = "instance #{@id}"
        attributes = create_optional_attributes(%i[agent_id job index cid expects_vm job_state has_processes])
      end

      "#{@deployment}: #{identifier} [#{attributes.join(', ')}]"
    end

    def expects_vm?
      !!@expects_vm
    end

    def vm?
      @cid != nil
    end

    private

    def create_optional_attributes(attributes)
      attributes.map do |attribute|
        value = send(attribute)
        "#{attribute}=#{value}" if value
      end.compact
    end

    def create_mandatory_attributes(attributes)
      attributes.map do |attribute|
        value = send(attribute)
        "#{attribute}=#{value}"
      end
    end
  end
end
