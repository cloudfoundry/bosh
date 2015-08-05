module Bosh::Cli::Command
  module Release
    class InspectRelease < Base

      usage 'inspect release'
      desc 'List all jobs, packages, and compiled packages associated with a release. Release must be in the form {name}/{version}'
      def inspect(release)
        auth_required
        show_current_state

        release = Bosh::Cli::NameVersionPair.parse(release)

        response = director.inspect_release(release.name, release.version)

        templates_table = build_jobs_table(response)
        say(templates_table.render)
        nl

        packages_table = build_packages_table(response)
        say(packages_table.render)
      end

      def build_jobs_table(release)
        table do |t|
          t.headings = 'Job', 'Fingerprint', 'Blobstore ID', 'SHA1'
          release['jobs'].each do |job|
            row = [
                job['name'].make_yellow,
                job['fingerprint'].make_yellow,
                job['blobstore_id'].make_yellow,
                job['sha1'].make_yellow]
            t << row
          end
        end
      end

      def build_packages_table(release)
        table do |t|
          t.headings = 'Package', 'Fingerprint', 'Compiled For', 'Blobstore ID', 'SHA1'
          release['packages'].each do |package|
            src_pkg_row = [
                package['name'].make_yellow,
                package['fingerprint'].make_yellow,
                package['blobstore_id'].nil? ? '(no source)'.make_red : '(source)'.make_yellow,
                package['blobstore_id'].nil? ? "" : package['blobstore_id'].make_yellow,
                package['sha1'].nil? ? "" : package['sha1'].make_yellow]
            t << src_pkg_row

            package['compiled_packages'].each do |compiled|
              comp_pkg_row = [
                  '',
                  '',
                  compiled['stemcell'].make_green,
                  compiled['blobstore_id'].make_green,
                  compiled['sha1'].make_green]
              t << comp_pkg_row
            end
          end
        end
      end

    end
  end
end
