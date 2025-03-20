require 'semi_semantic/version'
require 'bosh/version/release_version'
require 'bosh/version/version_list'

module Bosh
  module Version
    class ReleaseVersionList < VersionList

      # @param [Array<#version>] Collection of version strings
      def self.parse(versions)
        self.new(VersionList.parse(versions, ReleaseVersion).versions)
      end

      # @param [#version] ReleaseVersion from which to rebase the post-release segment
      def rebase(version)
        raise TypeError, "Failed to Rebase - Invalid Version Type: #{version.class}" unless version.is_a?(ReleaseVersion)

        # Can only rebase versions with a post-release segment
        if version.version.post_release.nil?
          raise ArgumentError, "Failed to Rebase - Invalid Version: #{version.inspect}"
        end

        latest = latest_with_pre_release(version)
        if latest
          if latest.version.post_release.nil?
            latest.default_post_release
          else
            latest.increment_post_release
          end
        else
          version.default_post_release
        end
      end
    end
  end
end
