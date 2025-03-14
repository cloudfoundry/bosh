require 'semi_semantic/version'
require 'bosh/version/parse_error'

module Bosh
  module Version
    class UnavailableMethodError < StandardError; end

    class SemiSemanticVersion
      include Comparable

      DEFAULT_POST_RELEASE_SEGMENT = SemiSemantic::VersionSegment.parse('build.1')

      attr_reader :version

      def self.parse(version)
        raise ArgumentError, 'Invalid Version: nil' if version.nil?
        version = version.to_s

        self.new(SemiSemantic::Version.parse(version))
      rescue SemiSemantic::ParseError => e
        raise ParseError.new(e)
      end

      def self.parse_and_compare(a, b)
        self.parse(a) <=> self.parse(b)
      end

      def initialize(version)
        raise ArgumentError, "Invalid Version Type: #{version.class}" unless version.is_a?(SemiSemantic::Version)
        @version = version
        @version.freeze
      end

      def default_post_release
        self.class.new(SemiSemantic::Version.new(@version.release, @version.pre_release, default_post_release_segment))
      end

      def increment_post_release
        raise UnavailableMethodError, 'Failed to increment: post-release is nil' if @version.post_release.nil?
        self.class.new(SemiSemantic::Version.new(@version.release, @version.pre_release, @version.post_release.increment))
      end

      def increment_release
        self.class.new(SemiSemantic::Version.new(@version.release.increment))
      end

      def timestamp_release
        self.class.new(SemiSemantic::Version.new(@version.release, @version.pre_release, SemiSemantic::VersionSegment.parse("dev." + Time.now.to_i.to_s)))
      end

      def <=>(other)
        @version <=> other.version
      end

      def to_s
        @version.to_s
      end

      private

      def default_post_release_segment
        DEFAULT_POST_RELEASE_SEGMENT
      end
    end
  end
end
