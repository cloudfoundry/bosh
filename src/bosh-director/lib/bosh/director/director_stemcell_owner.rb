require 'etc'

module Bosh::Director
  class DirectorStemcellOwner
    def initialize(unamer = Etc, file_owner = File)
      @unamer = unamer
      @file_owner = file_owner
    end

    def stemcell_os
      @stemcell_os ||= os_and_version
    end

    def stemcell_version
      return @stemcell_version unless @stemcell_version.nil?

      stemcell_version_path = '/var/vcap/bosh/etc/stemcell_version'
      return '-' unless @file_owner.exists?(stemcell_version_path)

      @stemcell_version = @file_owner.read(stemcell_version_path).chomp
    end

    private

    def os_and_version
      results = @unamer.uname[:version].scan(/~([^ ]*)-([^ ]*) .*$/)[0]
      return '-' if Array(results).empty?

      os = results[1].downcase
      version_number = results[0]
      version_name = if version_number.start_with?('16.')
                       'xenial'
                     elsif version_number.start_with?('14.')
                       'trusty'
                     elsif version_number.start_with?('18.')
                       'bionic'
                     else
                       version_number
                     end

      "#{os}-#{version_name}"
    end
  end
end
