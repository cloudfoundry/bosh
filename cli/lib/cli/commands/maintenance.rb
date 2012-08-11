# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Maintenance < Base
    include Bosh::Cli::VersionCalc

    RELEASES_TO_KEEP = 2
    STEMCELLS_TO_KEEP = 2

    # usage "cleanup"
    # desc  "Remove all but several recent stemcells and releases " +
    #           "from current director " +
    #           "(stemcells and releases currently in use are NOT deleted)"
    # route :maintenance, :cleanup
    def cleanup
      target_required
      auth_required

      releases_to_keep = RELEASES_TO_KEEP
      stemcells_to_keep = STEMCELLS_TO_KEEP

      release_wording = pluralize(releases_to_keep, "latest version")
      stemcell_wording = pluralize(stemcells_to_keep, "latest version")

      desc = <<-EOS.gsub(/^ */, "")
        Cleanup command will attempt to delete old unused
        release versions and stemcells from your currently
        targeted director at #{target_name.green}.

        Only #{release_wording.green} of each release
        and #{stemcell_wording.green} of each stemcell will be kept.

        Releases and stemcells that are in use will not be affected.
      EOS

      say("\n#{desc}\n")

      err("Cleanup canceled") unless confirmed?

      nl
      cleanup_stemcells(stemcells_to_keep)
      nl
      cleanup_releases(releases_to_keep)

      nl
      say("Cleanup complete".green)
    end

    private

    def cleanup_stemcells(n_to_keep)
      stemcells_by_name = director.list_stemcells.inject({}) do |h, stemcell|
        h[stemcell["name"]] ||= []
        h[stemcell["name"]] << stemcell
        h
      end

      delete_list = []
      say("Deleting old stemcells")

      stemcells_by_name.each_pair do |name, stemcells|
        stemcells.sort! do |sc1, sc2|
          version_cmp(sc1["version"], sc2["version"])
        end
        delete_list += stemcells[0...(-n_to_keep)]
      end

      if delete_list.size > 0
        delete_list.each do |stemcell|
          name, version = stemcell["name"], stemcell["version"]
          desc = "#{name}/#{version}"
          perform(desc) do
            director.delete_stemcell(name, version, :quiet => true)
          end
        end
      else
        say("  none found".yellow)
      end
    end

    def cleanup_releases(n_to_keep)
      delete_list = []
      say("Deleting old release versions")

      director.list_releases.each do |release|
        name = release["name"]
        versions = release["versions"].sort { |v1, v2| version_cmp(v1, v2) }

        versions[0...(-n_to_keep)].each do |version|
          delete_list << [name, version]
        end
      end

      if delete_list.size > 0
        delete_list.each do |name, version|
          desc = "#{name}/#{version}"
          perform(desc) do
            director.delete_release(name, :force => false,
                                    :version => version, :quiet => true)
          end
        end
      else
        say("  none found".yellow)
      end
    end

    def refresh(message)
      say("\r", "")
      say(" " * 80, "")
      say("\r#{message}", "")
    end

    def perform(desc)
      say("  #{desc.yellow.ljust(40)}", "")
      say("IN PROGRESS...".yellow, "")

      status, task_id = yield
      responses = {
        :done => "DELETED".green,
        :non_trackable => "CANNOT TRACK".red,
        :track_timeout => "TIMED OUT".red,
        :error => "ERROR".red,
      }

      refresh("  #{desc.yellow.ljust(40)}#{responses[status]}\n")

      if status == :error
        result = director.get_task_result(task_id)
        say("  #{result.to_s.red}")
      end

      status == :done
    end

  end
end
