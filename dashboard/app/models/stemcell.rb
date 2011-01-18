class Stemcell

  attr_reader :name, :version, :cid

  def self.all(director)
    director.list_stemcells.map do |data|
      new(data)
    end
  end

  def initialize(data)
    @name    = data["name"]
    @version = data["version"]
    @cid     = data["cid"]
  end
  
end
