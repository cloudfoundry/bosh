module Bosh::Cli::Command
  module Release
    class ListReleases < Base

      usage 'releases'
      desc 'Show the list of available releases'
      option '--jobs', 'include job templates'
      def list
        auth_required
        show_current_state
        releases = director.list_releases.sort do |r1, r2|
          r1['name'] <=> r2['name']
        end

        err('No releases') if releases.empty?

        currently_deployed = false
        uncommited_changes = false
        if releases.first.has_key? 'release_versions'
          releases_table = build_releases_table(releases, options)
          currently_deployed, uncommited_changes = release_version_details(releases)
        elsif releases.first.has_key? 'versions'
          releases_table = build_releases_table_for_old_director(releases)
          currently_deployed, uncommited_changes = release_version_details_for_old_director(releases)
        end

        nl
        say(releases_table.render)

        say('(*) Currently deployed') if currently_deployed
        say('(+) Uncommitted changes') if uncommited_changes
        nl
        say('Releases total: %d' % releases.size)
      end

      private
      def build_releases_table_for_old_director(releases)
        table do |t|
          t.headings = 'Name', 'Versions'
          releases.each do |release|
            versions = release['versions'].sort { |v1, v2|
              Bosh::Common::Version::ReleaseVersion.parse_and_compare(v1, v2)
            }.map { |v| ((release['in_use'] || []).include?(v)) ? "#{v}*" : v }

            t << [release['name'], versions.join(', ')]
          end
        end
      end

      # Builds table of release information
      # Default headings: "Name", "Versions", "Commit Hash"
      # Extra headings: options[:job] => "Jobs"
      def build_releases_table(releases, options = {})
        show_jobs = options[:jobs]
        table do |t|
          t.headings = 'Name', 'Versions', 'Commit Hash'
          t.headings << 'Jobs' if show_jobs
          releases.each do |release|
            versions, commit_hashes = formatted_versions(release['release_versions']).transpose
            row = [release['name'], versions.join("\n"), commit_hashes.join("\n")]
            if show_jobs
              jobs = formatted_jobs(release).transpose
              row << jobs.join("\n")
            end
            t << row
          end
        end
      end

      def formatted_versions(release_versions)
        if release_versions.empty?
          [["unknown", "unknown"]]
        else
          sort_versions(release_versions).map { |v| formatted_version_and_commit_hash(v) }
        end
      end

      def sort_versions(versions)
        versions.sort { |v1, v2| Bosh::Common::Version::ReleaseVersion.parse_and_compare(v1['version'], v2['version']) }
      end

      def formatted_version_and_commit_hash(version)
        version_number = version['version'] + (version['currently_deployed'] ? '*' : '')
        commit_hash = version['commit_hash'] + (version['uncommitted_changes'] ? '+' : '')
        [version_number, commit_hash]
      end

      def formatted_jobs(release)
        sort_versions(release['release_versions']).map do |v|
          if job_names = v['job_names']
            [job_names.join(', ')]
          else
            ['n/a  '] # with enough whitespace to match "Jobs" header
          end
        end
      end


      def release_version_details(releases)
        currently_deployed = false
        uncommitted_changes = false
        releases.each do |release|
          release['release_versions'].each do |version|
            currently_deployed ||= version['currently_deployed']
            uncommitted_changes ||= version['uncommitted_changes']
            if currently_deployed && uncommitted_changes
              return true, true
            end
          end
        end
        return currently_deployed, uncommitted_changes
      end

      def release_version_details_for_old_director(releases)
        currently_deployed = false
        # old director did not support uncommitted changes
        uncommitted_changes = false
        releases.each do |release|
          currently_deployed ||= release['in_use'].any?
          if currently_deployed
            return true, uncommitted_changes
          end
        end
        return currently_deployed, uncommitted_changes
      end
    end
  end
end
