module Bosh::Monitor
  class Agent
    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    ATTRIBUTES = %i[deployment job index instance_id cid job_state has_processes].freeze

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

    def is_not_running?
      @job_state.to_s != 'running' || @has_processes == false
    end

    def update_instance(instance)
      @job = instance.job
      @index = instance.index
      @cid = instance.cid
      @instance_id = instance.id
      @job_state = instance.job_state
      @has_processes = instance.has_processes
    end
  end
end
