require 'fileutils'
require 'bosh/dev/candidate_artifacts'

module Bosh::Dev
  class StemcellEnvironment
    attr_reader :stemcell_type,
                :infrastructure,
                :directory

    def initialize(stemcell_type, infrastructure = 'aws')
      @stemcell_type = stemcell_type
      @infrastructure = infrastructure
      @directory = File.join('/mnt/stemcells', "#{infrastructure}-#{stemcell_type}")
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
      files = Dir.glob("#{directory}/work/work/*.tgz")

      unless files.empty?
        stemcell = files.first
        stemcell_base = File.basename(stemcell, '.tgz')

        stemcell_file = File.join(ENV.to_hash.fetch('WORKSPACE'), "#{stemcell_base}.tgz")
        FileUtils.cp(stemcell, stemcell_file)

        if infrastructure == 'aws'
          candidate_artifacts = Bosh::Dev::CandidateArtifacts.new(stemcell_file)
          candidate_artifacts.publish
        end
      end
    end
  end
end
