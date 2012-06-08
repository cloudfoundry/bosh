require "posix/spawn" unless defined?(::POSIX::Spawn)

module Bosh::Exec::Adapters
  # execute a command using the posix-spawn gem
  class PosixSpawn
    def self.sh(command)
      child = ::POSIX::Spawn::Child.new(command)

      Bosh::Exec::Result.new(command, child.out, child.err, child.status.exitstatus)
    end
  end
end
