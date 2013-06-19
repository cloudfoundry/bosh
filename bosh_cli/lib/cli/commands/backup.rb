module Bosh::Cli::Command
  class Backup < Base

    usage "backup"
    desc "Backup BOSH"

    def backup(path="#{Dir.pwd}/bosh_backup.tgz")
      auth_required
      status, task_id = director.create_backup

      if status == :done
        tmp_path = director.fetch_backup
        FileUtils.mv(tmp_path, path)
        say("Backup of BOSH director was put in `#{path.yellow}'.")
      else
        [status, task_id]
      end
    end
  end
end
