require 'bosh/dev'
require 'tmpdir'

module Bosh::Dev
  class GemVersion
    attr_reader :version_number

    def initialize(version_number)
      raise ArgumentError.new('Version number must be specified.') unless version_number
      @version_number = version_number
    end

    def version
      @version_number.to_s
    end
  end
end
