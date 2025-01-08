module Bosh::Monitor
  class Agent
    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    ATTRIBUTES = %i[deployment job index instance_id cid].freeze

    ATTRIBUTES.each do |attribute|
      attr_accessor attribute
    end

    def initialize(id, opts = {})
      raise ArgumentError, 'Agent must have an id' if id.nil?

      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bosh::Monitor.logger
      @intervals     = Bosh::Monitor.intervals

      @deployment = opts[:deployment]
      @job = opts[:job]
      @index = opts[:index]
      @cid = opts[:cid]
      @instance_id = opts[:instance_id]
    end

    def name
      if @deployment && @job && @instance_id
        name = "#{@deployment}: #{@job}(#{@instance_id}) [id=#{@id}, "

        name += "index=#{@index}, " if @index

        name + "cid=#{@cid}]"
      else
        state = ATTRIBUTES.each_with_object([]) do |attribute, acc|
          value = send(attribute)
          acc << "#{attribute}=#{value}" if value
        end

        "agent #{@id} [#{state.join(', ')}]"
      end
    end

    def timed_out?
      (Time.now - @updated_at) > @intervals.agent_timeout
    end

    def rogue?
      (Time.now - @discovered_at) > @intervals.rogue_agent_alert && @deployment.nil?
    end

    def is_inactive?
      @logger.info("ABCDEF Job: #{@job}")
      @logger.info("ABCDEF Deployment: #{@deployment}")
      @logger.info("ABCDEF Instance agent id: #{@instance.agent_id}")
      @logger.info("ABCDEF Instance VM cid: #{@instance.vm_cid}")
      @logger.info("ABCDEF Expects VM: #{@instance.expects_vm}")
      @logger.info("ABCDEF Instance Job state: #{@instance.job_state}")
      @logger.info("ABCDEF Instance state: #{@instance.state}")
      (Time.now - @updated_at) > @intervals.agent_timeout
    end

    def update_instance(instance)
      @job = instance.job
      @index = instance.index
      @cid = instance.cid
      @instance_id = instance.id
      @instance = instance
    end
  end
end
