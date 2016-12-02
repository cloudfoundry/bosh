module Bosh::Cli
  class GlobMatch
    # Helper class encapsulating the data we know about the glob. We need
    # both directory and file path, as we match the same path in several
    # directories (src, src_alt, blobs)
    attr_reader :dir
    attr_reader :path

    def initialize(dir, path)
      @dir = dir
      @path = path
    end

    def full_path
      File.join(dir, path)
    end

    def <=>(other)
      @path <=> other.path
    end

    # GlobMatch will be used as Hash key (as implied by using Set),
    # hence we need to define both eql? and hash
    def eql?(other)
      @path == other.path
    end

    def hash
      @path.hash
    end
  end
end
