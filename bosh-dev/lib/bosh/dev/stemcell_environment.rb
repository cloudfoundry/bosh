require 'fileutils'

module Bosh::Dev
  class StemcellEnvironment
    def initialize(builder)
      @builder = builder
    end

    def sanitize
      FileUtils.rm_rf('*.tgz')

      system("sudo umount #{File.join(builder.work_path, 'work/mnt/tmp/grub/root.img')} 2> /dev/null")
      system("sudo umount #{File.join(builder.work_path, 'work/mnt')} 2> /dev/null")

      mnt_type = `df -T '#{builder.directory}' | awk '/dev/{ print $2 }'`
      mnt_type = 'unknown' if mnt_type.strip.empty?

      if mnt_type != 'btrfs'
        system("sudo rm -rf #{builder.directory}")
      end
    end

    private

    attr_reader :builder
  end
end
