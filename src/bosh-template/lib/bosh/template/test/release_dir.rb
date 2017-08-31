module Bosh::Template::Test
  class ReleaseDir
    def initialize(path)
      @path = path
    end

    def job(name)
      Bosh::Template::Test::Job.new(@path, name)
    end
  end
end