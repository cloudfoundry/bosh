require 'semi_semantic/version'

module Bosh::Common
  class VersionNumber
    DEFAULT_DEV_RELEASE_SEGMENT = SemiSemantic::VersionSegment.parse('dev.1')

    def self.parse(version)
      raise ArgumentError, 'Invalid Version: nil' if version.nil?
      #raise ArgumentError, "Invalid Version Type: #{version.class}" if version.is_a?(String)
      version = version.to_s

      #discard anything after a space, including the space, to support compound bosh versions
      version = version.split(' ', 2)[0] if version =~ / /

      #convert old-style dev version suffix to new dev post-release segment
      matches = /\A(?<release>.*)(\.(?<dev>[0-9]+)-dev)\z/.match(version)
      unless matches.nil?
        version = matches[:release] + "+dev." + matches[:dev]
      end

      #replace underscores with periods to maintain reverse compatibility with stemcell versions
      version = version.gsub('_', '.')

      SemiSemantic::Version.parse(version)
    end

    # @param [Array<#version>] Collection of version strings
    def self.parse_list(versions)
      versions.map { |v| self.parse(v) }
    end

    # @param [Array<#version>] Collection of version strings
    def self.latest(versions)
      versions.max
    end
  end
end
