module Bosh::Cli::Command
  class Maintenance < Base

    RELEASES_TO_KEEP = 2
    STEMCELLS_TO_KEEP = 2

    # bosh cleanup
    usage 'cleanup'
    desc 'Cleanup releases, stemcells and disks'
    option '--all', 'Remove all unused releases, stemcells and disks'
    def cleanup
      target_required
      auth_required
      show_current_state

      remove_all = !!options[:all]

      num_releases_to_keep = remove_all ? 0 : RELEASES_TO_KEEP
      num_stemcells_to_keep = remove_all ? 0 : STEMCELLS_TO_KEEP

      begin
        director.cleanup({'remove_all' => remove_all})
      rescue Bosh::Cli::ResourceNotFound
        # old directors won't have `cleanup` endpoint, therefore use legacy endpoints
        nl
        cleanup_stemcells(num_stemcells_to_keep)
        nl
        cleanup_releases(num_releases_to_keep)
      end
      nl
      say('Cleanup complete'.make_green)
    end

    private

    def cleanup_stemcells(n_to_keep)
      stemcells_by_name = director.list_stemcells.inject({}) do |h, stemcell|
        h[stemcell['name']] ||= []
        h[stemcell['name']] << stemcell
        h
      end

      delete_list = []
      say('Deleting old stemcells')
      stemcells_by_name.each_pair do |_, stemcells|
        stemcells.reject! { |stemcell| !stemcell['deployments'].empty? }
        sorted_stemcells = stemcells.sort do |sc1, sc2|
          Bosh::Common::Version::StemcellVersion.parse(sc1['version']) <=> Bosh::Common::Version::StemcellVersion.parse(sc2['version'])
        end

        delete_list.concat(trim_array(sorted_stemcells, n_to_keep))
      end

      delete_list.each do |stemcell|
        name, version = stemcell['name'], stemcell['version']
        desc = "#{name}/#{version}"
        perform(desc) do
          director.delete_stemcell(name, version, :quiet => true)
        end
      end

       say('  none found'.make_yellow) if delete_list.size == 0
    end

    def cleanup_releases(n_to_keep)
      delete_list = []
      say('Deleting old release versions')

      director.list_releases.each do |release|
        name = release['name']
        versions = release['release_versions'].map { |release_version| release_version['version'] }
        currently_deployed = release['release_versions']
                               .select { |release_version| release_version['currently_deployed'] }
                               .map { |release_version| release_version['version'] }

        version_tuples = versions.map do |v|
          {
            provided: v,
            parsed: Bosh::Common::Version::ReleaseVersion.parse(v)
          }
        end
        versions = version_tuples.sort_by { |v| v[:parsed] }.map { |v| v[:provided] }

        trim_array(versions, n_to_keep).each do |version|
          delete_list << [name, version] unless currently_deployed.include?(version)
        end
      end

      delete_list.each do |name, version|
        desc = "#{name}/#{version}"
        perform(desc) do
          director.delete_release(name, :force => false,
                                  :version => version, :quiet => true)
        end
      end

      say('  none found'.make_yellow) if delete_list.size == 0
    end

    def trim_array(array, n_to_keep)
      n_to_keep > 0 ? array[0...(-n_to_keep)] : array
    end

    def refresh(message)
      say("\r", '')
      say(' ' * 80, '')
      say("\r#{message}", '')
    end

    def perform(desc)
      say("  #{desc.make_yellow.ljust(40)}", '')
      say(' IN PROGRESS...'.make_yellow, '')

      status, task_id = yield
      responses = {
        :done => 'DELETED'.make_green,
        :non_trackable => 'CANNOT TRACK'.make_red,
        :track_timeout => 'TIMED OUT'.make_red,
        :error => 'ERROR'.make_red,
      }

      refresh("  #{desc.make_yellow.ljust(50)}#{responses[status]}\n")

      if status == :error
        result = director.get_task_result(task_id)
        say("  #{result.to_s.make_red}")
      end

      status == :done
    end
  end
end
