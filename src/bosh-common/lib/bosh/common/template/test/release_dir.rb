require 'bosh/common/template/test/job'

module Bosh::Common::Template::Test
  class ReleaseDir
    def initialize(path)
      @path = path
    end

    def job(name)
      Job.new(@path, name)
    end
  end
end
