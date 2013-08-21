require 'bosh/dev'
require 'tmpdir'

module Bosh::Dev
  class VersionFile
    BOSH_VERSION_FILE = 'BOSH_VERSION'

    attr_reader :version_number

    def initialize(version_number)
      raise ArgumentError.new('Version number must be specified.') unless version_number

      @version_number = version_number
    end

    def write
      File.write(BOSH_VERSION_FILE, updated_version_string)
    end

    private

    def existing_version_string
      File.read(BOSH_VERSION_FILE)
    end

    def updated_version_string
      existing_version_string.gsub(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{version_number}")
    end
  end
end
