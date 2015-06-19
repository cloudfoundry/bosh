module Bosh::Cli::Command
  class Backup < Base

    usage 'backup'
    desc 'Backup BOSH'
    option '--force', 'Overwrite if the backup file already exists'
    def backup(path=nil)
      auth_required
      show_current_state

      path = backup_destination_path(path)

      status, task_id = director.create_backup

      if status == :done
        tmp_path = director.fetch_backup
        FileUtils.mv(tmp_path, path)
        say("Backup of BOSH director was put in `#{path.make_green}'.")
      else
        [status, task_id]
      end
    end

    private

    def force?
      !!options[:force]
    end

    def backup_destination_path(dest_path)
      path = Bosh::Cli::BackupDestinationPath.new(director).create_from_path(dest_path)

      if File.exists?(path) && !force?
        err("There is already an existing file at `#{path}'. " +
              'To overwrite it use the --force option.')
      end

      path
    end
  end
end
