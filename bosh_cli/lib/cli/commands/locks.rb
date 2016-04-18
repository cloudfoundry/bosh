module Bosh::Cli::Command
  class Locks < Base

    usage 'locks'
    desc 'Show list of current locks'
    def locks
      auth_required
      show_current_state

      locks = director.list_locks
      if locks.empty?
        nl
        say('No locks')
        nl
        return
      end

      show_locks_table(locks)
      say("Locks total: %d" % locks.size)
    end

    private

    def show_locks_table(locks)
      locks_table = table do |t|
        t.headings = ['Type', 'Resource', 'Expires at']
        locks.each do |lock|
          t << [lock['type'], lock['resource'].join(':'), Time.at(lock['timeout'].to_i).utc]
        end
      end

      nl
      say(locks_table)
      nl
    end
  end
end
