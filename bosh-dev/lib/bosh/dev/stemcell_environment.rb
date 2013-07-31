require 'fileutils'
require 'bosh/dev/stemcell'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class StemcellEnvironment
    attr_reader :stemcell_type,
                :infrastructure,
                :directory,
                :build_path,
                :work_path,
                :stemcell_version

    def initialize(stemcell_type, infrastructure = 'aws')
      @stemcell_type = stemcell_type
      @infrastructure = infrastructure
      mnt = ENV.fetch('FAKE_MNT', '/mnt')
      @directory = File.join(mnt, 'stemcells', "#{infrastructure}-#{stemcell_type}")
      @work_path = File.join(directory, 'work')
      @build_path = File.join(directory, 'build')
      @stemcell_version = ENV.to_hash.fetch('BUILD_ID')
    end

    def sanitize
      FileUtils.rm_rf('*.tgz')

      system("sudo umount #{File.join(directory, 'work/work/mnt/tmp/grub/root.img')} 2> /dev/null")
      system("sudo umount #{File.join(directory, 'work/work/mnt')} 2> /dev/null")

      mnt_type = `df -T '#{directory}' | awk '/dev/{ print $2 }'`
      mnt_type = 'unknown' if mnt_type.strip.empty?

      if mnt_type != 'btrfs'
        system("sudo rm -rf #{directory}")
      end
    end

    def publish
      stemcell = Stemcell.new(stemcell_filename)

      Pipeline.new.publish_stemcell(stemcell.create_light_stemcell) if infrastructure == 'aws'

      Pipeline.new.publish_stemcell(stemcell)
    end

    private

    def stemcell_filename
      @stemcell_filename ||=
        Dir.glob("#{directory}/work/work/*.tgz").first # see: stemcell_builder/stages/stemcell/apply.sh:48
    end
  end
end
