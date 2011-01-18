class Release

  attr_reader :name, :versions

  def self.all(director)
    director.list_releases.map do |data|
      new(data)
    end
  end

  def initialize(data)
    @name     = data["name"]
    @versions = data["versions"]
  end
  
end
