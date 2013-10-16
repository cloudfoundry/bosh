module Bosh::Agent
  class DiskUtil
    class << self
      def logger
        Bosh::Agent::Config.logger
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def mount_entry(partition)
        `mount`.lines.select { |l| l.match(/#{partition}/) }.first
      end

      GUARD_RETRIES = 600
      GUARD_SLEEP = 1

      def umount_guard(mountpoint)
        umount_attempts = GUARD_RETRIES

        loop do
          umount_output = `umount #{mountpoint} 2>&1`

          if $?.exitstatus == 0
            break
          elsif umount_attempts != 0 && umount_output =~ /device is busy/
            #when umount2 syscall fails and errno == EBUSY, umount.c outputs:
            # "umount: %s: device is busy.\n"
            sleep GUARD_SLEEP
            umount_attempts -= 1
          else
            raise Bosh::Agent::MessageHandlerError,
                  "Failed to umount #{mountpoint}: #{umount_output}"
          end
        end

        attempts = GUARD_RETRIES - umount_attempts
        logger.info("umount_guard #{mountpoint} succeeded (#{attempts})")
      end

      # Pay a penalty on this check the first time a persistent disk is added to a system
      def ensure_no_partition?(disk, partition)
        check_count = 2
        check_count.times do
          if sfdisk_lookup_partition(disk, partition).empty?
            # keep on trying
          else
            if File.blockdev?(partition)
              return false # break early if partition is there
            end
          end
          sleep 1
        end

        # Double check that the /dev entry is there
        if File.blockdev?(partition)
          return false
        else
          return true
        end
      end

      def sfdisk_lookup_partition(disk, partition)
        `sfdisk -Llq #{disk}`.lines.select { |l| l.match(%q{/\A#{partition}.*83.*Linux}) }
      end

      def get_usage
        usage = {
          :system => {:percent => fs_usage_safe('/')}
        }
        ephemeral_percent = fs_usage_safe(File.join(base_dir, 'data'))
        usage[:ephemeral] = {:percent => ephemeral_percent} if ephemeral_percent
        persistent_percent = fs_usage_safe(File.join(base_dir, 'store'))
        usage[:persistent] = {:percent => persistent_percent} if persistent_percent

        usage
      end

      private
      # Calculate file_system_usage
      def fs_usage_safe(path)
        sigar = SigarBox.create_sigar
        fs_list = sigar.file_system_list

        fs = fs_list.find {|fs| fs.dir_name == path}
        return unless fs

        usage = sigar.file_system_usage(path)
        (usage.use_percent * 100).to_i.to_s
      end

    end
  end
end
