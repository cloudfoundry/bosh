require 'cli/name_id_pair'

module Bosh::Cli::Command
  class Ignore < Base

    usage "ignore instance"
    desc "Ignore an instance. 'name_and_id' should be in the form of {name}/{id}"
    def ignore(name_and_id)
      change_ignore_state(name_and_id, true)
    end

    usage "unignore instance"
    desc "Unignore an instance. 'name_and_id' should be in the form of {name}/{id}"
    def unignore(name_and_id)
      change_ignore_state(name_and_id, false)
    end

    private

    def change_ignore_state(name_and_id, desired_state)
      auth_required
      deployment_required

      instance_pair = Bosh::Cli::NameIdPair.parse(name_and_id)
      manifest = prepare_deployment_manifest(show_state: true)

      director.change_instance_ignore_state(manifest.name, instance_pair.name, instance_pair.id, desired_state)
    end

  end
end
