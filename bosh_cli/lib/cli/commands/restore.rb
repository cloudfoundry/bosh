module Bosh::Cli::Command
class Restore < Base
    usage 'restore'
    desc 'Restore BOSH director database'
    def restore(path)
      auth_required
      show_current_state

      nl
      say("You are going to restore the director's database.".make_red)
      nl
      say('THIS IS A VERY DESTRUCTIVE OPERATION WHICH WILL DROP CURRENT DATABASE.'.make_red)
      nl
      say('IT CANNOT BE UNDONE!'.make_red)
      nl

      unless confirmed?
        say('Canceled restoring database'.make_green)
        return
      end

      err("The file '#{path}' does not exist.".make_red) unless File.exists?(path)
      err("The file '#{path}' is not readable.".make_red) unless File.readable?(path)

      nl
      status = director.restore_db(path)
      err("Failed to restore the database, the status is '#{status}'") unless status == 202
      nl
      say('Starting restore of BOSH director.')

      result = director.check_director_restart(5, 600)

      unless result
        err('Restore database timed out.')
      else
        say('Restore done!'.make_green)
      end
    end
  end
end
