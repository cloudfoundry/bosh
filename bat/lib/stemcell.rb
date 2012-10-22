class Stemcell
  attr_reader :path
  attr_reader :name
  attr_reader :cpi
  attr_reader :version

  def self.from_path(path)
    %r{/*(?<name>[\w-]+)-(?<cpi>[^-]+)-(?<version>[^-]+)\.tgz} =~ path
    Stemcell.new(name, version, cpi, path)
  end

  def initialize(name, version, cpi=nil, path=nil)
    @name = name
    @version = version
    @cpi = cpi
    @path = path
  end

  def to_s
    "#@name-#@version"
  end

  def to_path
    @path
  end

  def ==(other)
    to_s == other.to_s
  end

end
