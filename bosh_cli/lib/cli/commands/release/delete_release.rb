module Bosh::Cli::Command
  module Release
    class DeleteRelease < Base

      usage 'delete release'
      desc 'Delete release (or a particular release version)'
      option '--force', 'ignore errors during deletion'
      def delete(name, version = nil)
        auth_required
        show_current_state
        force = !!options[:force]

        desc = "#{name}"
        desc << "/#{version}" if version

        if force
          say("Deleting `#{desc}' (FORCED DELETE, WILL IGNORE ERRORS)".make_red)
        else
          say("Deleting `#{desc}'".make_red)
        end

        if confirmed?
          status, task_id = director.delete_release(name, force: force, version: version)
          task_report(status, task_id, "Deleted `#{desc}'")
        else
          say('Canceled deleting release'.make_green)
        end
      end
    end
  end
end


