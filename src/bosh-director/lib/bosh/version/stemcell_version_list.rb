require 'semi_semantic/version'
require 'bosh/version/stemcell_version'
require 'bosh/version/version_list'

module Bosh
  module Version
    class StemcellVersionList < VersionList

      # @param [Array<#version>] Collection of version strings
      def self.parse(versions)
        self.new(VersionList.parse(versions, StemcellVersion).versions)
      end
    end
  end
end
