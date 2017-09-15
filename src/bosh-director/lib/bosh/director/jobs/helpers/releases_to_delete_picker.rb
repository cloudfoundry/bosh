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
              .map { |version| version['version'] }
              .slice(0..(-releases_to_keep - 1))
          }
        end

        unused_releases.reject{ |release| release['versions'].empty? }
      end
    end
  end
end
