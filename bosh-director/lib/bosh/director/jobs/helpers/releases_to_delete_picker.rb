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
          release['release_versions'].reject! { |version| version['currently_deployed'] }
          release
        end

        unused_releases_to_delete = unused_releases
                                      .reject{ |release| release['release_versions'].empty? }
                                      .map do |release|
          release['release_versions'].pop(releases_to_keep)
          release
        end

        unused_releases_to_delete.map do |release|
          release['release_versions'].map do |version|
            {'name' => release['name'], 'version' => version['version']}
          end
        end.flatten
      end
    end
  end
end
