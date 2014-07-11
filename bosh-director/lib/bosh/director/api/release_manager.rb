module Bosh::Director
  module Api
    class ReleaseManager
      include ApiHelper

      # Finds release by name
      # @param [String] name Release name
      # @return [Models::Release]
      # @raise [ReleaseNotFound]
      def find_by_name(name)
        release = Models::Release[:name => name]
        if release.nil?
          raise ReleaseNotFound, "Release `#{name}' doesn't exist"
        end
        release
      end

      # @param [Models::Release] release Release model
      # @param [String] version Release version
      # @return [Models::ReleaseVersion] Release version model
      # @raise [ReleaseVersionInvalid, ReleaseVersionNotFound]
      def find_version(release, version)
        dataset = release.versions_dataset

        release_version = dataset.filter(:version => version).first
        if release_version.nil?
          begin
            new_formatted_version = Bosh::Common::Version::ReleaseVersion.parse(version)
          rescue SemiSemantic::ParseError
            raise ReleaseVersionInvalid, "Release version invalid: #{version}"
          end
          if version == new_formatted_version.to_s
            old_formatted_version = new_formatted_version.to_old_format
            if old_formatted_version
              release_version = dataset.filter(:version => old_formatted_version).first
            end
          else
            release_version = dataset.filter(:version => new_formatted_version.to_s).first
          end
          if release_version.nil?
            raise ReleaseVersionNotFound,
                  "Release version `#{release.name}/#{version}' doesn't exist"
          end
        end

        release_version
      end

      def create_release_from_url(user, release_url, rebase)
        options = { remote: true, rebase: rebase }
        JobQueue.new.enqueue(user, Jobs::UpdateRelease, 'create release', [release_url, options])
      end

      def create_release_from_file_path(user, release_path, rebase)
        unless File.exists?(release_path)
          raise DirectorError, "Failed to create release: file not found - #{release_path}"
        end

        options = { rebase: rebase }
        JobQueue.new.enqueue(user, Jobs::UpdateRelease, 'create release', [release_path, options])
      end

      def delete_release(user, release, options = {})
        JobQueue.new.enqueue(user, Jobs::DeleteRelease, "delete release: #{release.name}", [release.name, options])
      end
    end
  end
end
