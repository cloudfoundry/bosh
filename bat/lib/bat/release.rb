module Bat
  class Release
    attr_reader :name, :path

    def self.from_path(path)
      name = 'bat'

      final_releases = Dir.glob(File.join(path, 'releases', "#{name}-*.yml"))
      dev_releases   = Dir.glob(File.join(path, 'dev_releases', "#{name}-*.yml"))

      paths = (final_releases + dev_releases).sort
      raise "Found no final or dev releases for #{name} release in #{path}" if paths.empty?

      versions = paths.map { |p| p.match(%r{/#{name}-([^/]+)\.yml})[1] }
      Release.new(name, versions, path)
    end

    def initialize(name, versions, path = nil)
      @name = name
      @versions = versions
      @path = path
    end

    def version
      latest
    end

    def to_s
      "#{name}-#{version}"
    end

    def to_path
      file_name = "#{name}-#{version}.yml"
      if dev?
        File.join(@path, 'dev_releases', file_name)
      else
        File.join(@path, 'releases', file_name)
      end
    end

    def sorted_versions
      # Takes care of final and dev versions
      # e.g. ["1", "12", "2", "2.1-dev", "3"]
      @sorted_versions ||= @versions.sort_by { |v| v.to_f }
    end

    def latest
      sorted_versions.last
    end

    def previous
      if sorted_versions.size < 2
        raise "Found no previous version for #{@name} release"
      else
        Release.new(@name, sorted_versions.dup[0..-2], @path)
      end
    end

    def ==(other)
      if other.is_a?(Release) && other.name == name
        common_versions = other.sorted_versions & sorted_versions
        !(common_versions).empty?
      end
    end

    private

    def dev?
      version =~ /-dev$/
    end
  end
end
