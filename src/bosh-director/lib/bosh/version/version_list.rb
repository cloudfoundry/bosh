require 'semi_semantic/version'

module Bosh
  module Version
    class VersionList
      include Enumerable

      attr_reader :versions

      alias :latest :max

      # @param [Array<#version>] Collection of version strings
      # @param [class] Version type to parse as (ex: SemiSemanticVersion, ReleaseVersion, StemcellVersion, BoshVersion)
      def self.parse(versions, version_type)
        raise TypeError, "Failed to Parse - Invalid Version Type: '#{version_type.inspect}'" unless version_type <= SemiSemanticVersion
        self.new(versions.map { |v| version_type.parse(v) })
      end

      # @param [Array<#version>] Collection of SemiSemanticVersion objects
      def initialize(versions)
        raise TypeError, "Invalid Version Array: '#{versions.inspect}'" unless versions.kind_of?(Array)
        @versions = versions
      end

      # Gets the latest version with the same release and pre-release version as the specified version
      # @param [#version] SemiSemanticVersion object
      def latest_with_pre_release(version)
        raise TypeError, "Invalid Version Type: #{version.class}" unless version.kind_of?(SemiSemanticVersion)
        @versions.select { |v|
          v.version.release == version.version.release && v.version.pre_release == version.version.pre_release
        }.max
      end

      # Gets the latest version with the same release version as the specified version
      # @param [#version] SemiSemanticVersion object
      def latest_with_release(version)
        raise TypeError, "Invalid Version Type: #{version.class}" unless version.kind_of?(SemiSemanticVersion)
        @versions.select { |v|
          v.version.release == version.version.release
        }.max
      end

      def each(&block)
        @versions.each(&block)
      end

      def ==(other)
        @versions == other.versions
      end

      def to_s
        @versions.map{ |v| v.to_s }.to_s
      end
    end
  end
end
