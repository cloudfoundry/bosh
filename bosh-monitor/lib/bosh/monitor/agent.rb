module Bosh::Monitor
  class Agent

    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    ATTRIBUTES = [ :deployment, :job, :index, :instance_id, :cid ]

    ATTRIBUTES.each do |attribute|
      attr_accessor attribute
    end

    def initialize(id, opts={})
      raise ArgumentError, "Agent must have an id" if id.nil?

      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bhm.logger
      @intervals     = Bhm.intervals

      @deployment = opts[:deployment]
      @job = opts[:job]
      @index = opts[:index]
      @cid = opts[:cid]
      @instance_id = opts[:instance_id]
    end

    def name
      if @deployment && @job && @instance_id
        name = "#{@deployment}: #{@job}(#{@instance_id}) [id=#{@id}, "

        if @index
          name = name + "index=#{@index}, "
        end

        name + "cid=#{@cid}]"
      else
        state = ATTRIBUTES.inject([]) do |acc, attribute|
          value = send(attribute)
          acc << "#{attribute}=#{value}" if value
          acc
        end

        "agent #{@id} [#{state.join(", ")}]"
      end
    end

    def timed_out?
      (Time.now - @updated_at) > @intervals.agent_timeout
    end

    def rogue?
      (Time.now - @discovered_at) > @intervals.rogue_agent_alert && @deployment.nil?
    end
  end
end
