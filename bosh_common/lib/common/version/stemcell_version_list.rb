require 'semi_semantic/version'
require 'common/version/stemcell_version'
require 'common/version/version_list'

module Bosh::Common
  module Version
    class StemcellVersionList < VersionList

      # @param [Array<#version>] Collection of version strings
      def self.parse(versions)
        self.new(VersionList.parse(versions, StemcellVersion).versions)
      end
    end
  end
end
