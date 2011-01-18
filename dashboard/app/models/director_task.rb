class DirectorTask

  attr_reader :id, :state, :timestamp, :result

  def self.running(director)
    director.list_running_tasks.map do |data|
      new(data)
    end
  end

  def self.recent(director)
    director.list_recent_tasks.map do |data|
      new(data)
    end    
  end

  def initialize(data)
    @id        = data["id"]
    @state     = data["state"]
    @timestamp = data["timestamp"].to_i
    @result    = data["result"]
  end
  
end
