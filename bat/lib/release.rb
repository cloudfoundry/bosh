class Release
  attr_reader :name
  attr_reader :paths
  attr_reader :versions
  attr_reader :path

  def self.from_path(path, name="bat")
    glob = File.join(path, "releases", "#{name}-*.yml")
    paths = Dir.glob(glob).sort
    raise "no matches" if paths.empty?
    versions = paths.map { |p| p.match(%r{/#{name}-([^/]+)\.yml})[1] }
    Release.new(name, versions, path)
  end

  def initialize(name, versions, path=nil)
    @name = name
    @versions = versions
    @path = path
  end

  def to_s
    "#{name}-#{version}"
  end

  def to_path
    file = "#{to_s}.yml"
    File.join(@path, "releases", file)
  end

  def version
    latest
  end

  def latest
    @versions.last
  end

  def previous
    raise "no previous version" if @versions.size < 2
    versions = @versions.dup
    versions.pop
    Release.new(@name, versions, @path)
  end

  def ==(other)
    if other.is_a?(Release) && other.name == name
      !(other.versions & versions).empty?
    end
  end
end
