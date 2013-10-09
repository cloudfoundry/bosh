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

    def version
      File.read(BOSH_VERSION_FILE).strip
    end

    def write
      File.write(BOSH_VERSION_FILE, updated_version_string)
    end

    private

    def updated_version_string
      version.gsub(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{version_number}\n")
    end
  end
end
