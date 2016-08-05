module Bosh::Monitor
  class Instance

    attr_reader :id
    ATTRIBUTES = [:agent_id, :job, :index, :cid, :expects_vm ]
    ATTRIBUTES.each do |attribute|
      attr_reader attribute
    end
    attr_accessor :deployment

    def initialize(instance_data)
      @logger = Bhm.logger
      @id     = instance_data['id']
      @agent_id = instance_data['agent_id']
      @job = instance_data['job']
      @index = instance_data['index']
      @cid = instance_data['cid']
      @expects_vm = instance_data['expects_vm']
    end

    def self.create(instance_data)
      unless instance_data.kind_of?(Hash)
        Bhm.logger.error("Invalid format for Instance data: expected Hash, got #{instance_data.class}: #{instance_data}")
        return nil
      end

      unless instance_data['id']
        Bhm.logger.error("Instance data has no id: got #{instance_data}")
        return nil
      end

      Instance.new(instance_data)
    end

    def name
      if @job
        name = "#{@deployment}: #{@job}(#{@id}) ["
        name = name + "agent_id=#{@agent_id}, " if @agent_id
        name = name + "index=#{@index}, " if @index
        name + "cid=#{@cid}]"
      else
        state = ATTRIBUTES.inject([]) do |acc, attribute|
          value = send(attribute)
          acc << "#{attribute}=#{value}" if value
          acc
        end

        "#{deployment}: instance #{@id} [#{state.join(", ")}]"
      end
    end

    def has_vm?
      @cid != nil
    end
  end
end
