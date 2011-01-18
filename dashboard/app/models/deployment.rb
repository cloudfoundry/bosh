class Deployment

  attr_reader :name

  def self.all(director)
    director.list_deployments.map do |data|
      new(data)
    end
  end

  def initialize(data)
    @name = data["name"]
  end
  
end
