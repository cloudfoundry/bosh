module Bosh::Director
  class DirectorStemcellOwner
    OS_RELEASE_FILE = '/etc/os-release'.freeze
    OPERATING_SYSTEM_FILE = '/var/vcap/bosh/etc/operating_system'.freeze
    STEMCELL_VERSION_FILE = '/var/vcap/bosh/etc/stemcell_version'.freeze

    def stemcell_os
      @stemcell_os ||= os_and_version
    end

    def stemcell_version
      return @stemcell_version unless @stemcell_version.nil?

      return '-' unless File.exist?(STEMCELL_VERSION_FILE)

      @stemcell_version = File.read(STEMCELL_VERSION_FILE).chomp
    end

    private

    def os_and_version
      os = read_operating_system
      codename = read_codename

      return '-' if os.nil? || codename.nil?

      "#{os}-#{codename}"
    end

    def read_operating_system
      if File.exist?(OPERATING_SYSTEM_FILE)
        return File.read(OPERATING_SYSTEM_FILE).chomp.downcase
      end

      return nil unless File.exist?(OS_RELEASE_FILE)

      File.readlines(OS_RELEASE_FILE).each do |line|
        if line =~ /^ID=(.+)$/
          return ::Regexp.last_match(1).strip.delete('"').downcase
        end
      end

      nil
    end

    def read_codename
      return nil unless File.exist?(OS_RELEASE_FILE)

      File.readlines(OS_RELEASE_FILE).each do |line|
        if line =~ /^UBUNTU_CODENAME=(.+)$/
          return ::Regexp.last_match(1).strip.delete('"')
        end
      end

      nil
    end
  end
end
