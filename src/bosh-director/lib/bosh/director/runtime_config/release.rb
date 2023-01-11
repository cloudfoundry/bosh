module Bosh::Director
  module RuntimeConfig
    class Release
      extend ValidationHelper

      attr_reader :name, :version

      def initialize(name, version, release_hash)
        @name = name
        @version = version
        @release_hash = release_hash
        validate
      end

      def self.parse(release_hash)
        name = safe_property(release_hash, 'name', :class => String)
        version = safe_property(release_hash, 'version', :class => String)
        new(name, version, release_hash)
      end

      def add_to_deployment(deployment)
        deployment_release = deployment.release(@name)
        if deployment_release
          ensure_same_name_and_version(deployment_release)
        else
          release_version = DeploymentPlan::ReleaseVersion.parse(deployment.model, @release_hash)
          release_version.bind_model
          deployment.add_release(release_version)
        end
      end

      private

      def ensure_same_name_and_version(deployment_release)
        if deployment_release.version != @version.to_s
          raise RuntimeInvalidDeploymentRelease, "Runtime manifest specifies release '#{@name}' with version as '#{@version}'. " +
            "This conflicts with version '#{deployment_release.version}' specified in the deployment manifest."
        end
      end

      def validate
        if @version.to_s =~ /(^|[\._])latest$/
          raise RuntimeInvalidReleaseVersion,
            "Runtime manifest contains the release '#{@name}' with version as '#{@version}'. " +
              'Please specify the actual version string.'
        end
      end
    end
  end
end
