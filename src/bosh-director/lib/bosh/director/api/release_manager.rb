module Bosh::Director
  module Api
    class ReleaseManager
      include ApiHelper

      def get_all_releases
        Models::Release.order_by(Sequel.asc(:name)).map do |release|
          release_versions = sorted_release_versions(release)
          {
            'name' => release.name,
            'release_versions' => release_versions
          }
        end
      end

      def sorted_release_versions(release, prefix = nil)
        sorted_version_tuples = release.versions_dataset.all.map do |version|
          {
            provided: version,
            parsed: Bosh::Version::ReleaseVersion.parse(version.values[:version])
          }
        end.sort_by { |rv| rv[:parsed] }

        unless prefix.nil?
          sorted_version_tuples = sorted_version_tuples.select do |version_tuple|
            /^#{prefix}([\.\-\+]|$)/.match(version_tuple[:provided].version.to_s)
          end
        end

        sorted_version_tuples.map do |version|
          provided = version[:provided]
          {
            'version' => provided.version.to_s,
            'commit_hash' => provided.commit_hash,
            'uncommitted_changes' => provided.uncommitted_changes,
            'currently_deployed' => !provided.deployments.empty?,
            'job_names' => provided.templates.map(&:name),
          }
        end
      end

      def find_by_name(name)
        release = Models::Release[:name => name]
        if release.nil?
          raise ReleaseNotFound, "Release '#{name}' doesn't exist"
        end
        release
      end

      def find_version(release, version)
        dataset = release.versions_dataset

        release_version = dataset.filter(version: version.to_s).first
        if release_version.nil?
          begin
            new_formatted_version = Bosh::Version::ReleaseVersion.parse(version)
          rescue Bosh::Version::ParseError
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
                  "Release version '#{release.name}/#{version}' doesn't exist"
          end
        end

        release_version
      end

      def create_release_from_url(username, release_url, options)
        options[:remote] = true
        JobQueue.new.enqueue(username, Jobs::UpdateRelease, 'create release', [release_url, options])
      end

      def create_release_from_file_path(username, release_path, options)
        unless File.exist?(release_path)
          raise DirectorError, "Failed to create release: file not found - #{release_path}"
        end

        JobQueue.new.enqueue(username, Jobs::UpdateRelease, 'create release', [release_path, options])
      end

      def delete_release(username, release, options = {})
        JobQueue.new.enqueue(username, Jobs::DeleteRelease, "delete release: #{release.name}", [release.name, options])
      end

      def export_release(username, deployment_name, release_name, release_version, stemcell_os, stemcell_version, sha2, jobs)
        JobQueue.new.enqueue(
          username,
          Jobs::ExportRelease,
          "export release: '#{release_name}/#{release_version}' for '#{stemcell_os}/#{stemcell_version}'",
          [deployment_name, release_name, release_version, stemcell_os, stemcell_version, sha2, :jobs => jobs])
      end
    end
  end
end
