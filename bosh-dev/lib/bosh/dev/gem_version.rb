require 'bosh/dev'
require 'tmpdir'

module Bosh::Dev
  class GemVersion
    attr_reader :minor_version_number

    MAJOR_VERSION_NUMBER = 1
    GEM_PATCH_LEVEL = 0

    def initialize(minor_version_number)
      raise ArgumentError.new('Minor version number must be specified.') unless minor_version_number
      @minor_version_number = minor_version_number
    end

    def version
      "#{MAJOR_VERSION_NUMBER}.#{minor_version_number}.#{GEM_PATCH_LEVEL}"
    end
  end
end
