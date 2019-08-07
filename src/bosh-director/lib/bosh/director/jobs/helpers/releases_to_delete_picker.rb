module Bosh::Director::Jobs
  module Helpers
    class ReleasesToDeletePicker
      def initialize(release_manager)
        @release_manager = release_manager
      end

      def pick(releases_to_keep)
        unused_releases = @release_manager
          .get_all_releases
          .map do |release|
          {
            'name' => release['name'],
            'versions' => release['release_versions']
              .reject { |version| version['currently_deployed'] }
              .reject { |version| version_is_present?(release['name'], version['version'], runtime_config_release_versions) }
              .map { |version| version['version'] }
              .slice(0..(-releases_to_keep - 1)),
          }
        end

        unused_releases.reject { |release| release['versions'].empty? }
      end

      private

      def version_is_present?(name, version, release_versions)
        release_versions.any? { |v| v.release.name == name && v.version.to_s == version }
      end

      def runtime_config_release_versions
        return @runtime_config_release_versions if @runtime_config_release_versions

        runtime_config_parser = Bosh::Director::RuntimeConfig::RuntimeManifestParser.new(Bosh::Director::Config.logger)
        runtime_config_models = Bosh::Director::Models::Config.latest_set('runtime')

        runtime_config_releases = runtime_config_models.map do |model|
          runtime_config_parser.parse(model.raw_manifest).releases
        end.flatten

        @runtime_config_release_versions = runtime_config_releases.map do |release|
          release_model = @release_manager.find_by_name(release.name)
          @release_manager.find_version(release_model, release.version)
        rescue Bosh::Director::ReleaseNotFound
          nil
        end.compact
      end
    end
  end
end
