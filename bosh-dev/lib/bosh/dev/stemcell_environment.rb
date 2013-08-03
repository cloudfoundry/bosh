require 'fileutils'
require 'bosh/stemcell/stemcell'
require 'bosh/stemcell/aws/light_stemcell'
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

    def create_micro_stemcell
      ENV['BUILD_PATH'] = build_path
      ENV['WORK_PATH'] = work_path
      ENV['STEMCELL_VERSION'] = stemcell_version

      bosh_release_path = Bosh::Dev::Build.candidate.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, infrastructure, Bosh::Dev::Build.candidate.number)
    end

    def create_basic_stemcell
      ENV['BUILD_PATH'] = build_path
      ENV['WORK_PATH'] = work_path
      ENV['STEMCELL_VERSION'] = stemcell_version

      Rake::Task['stemcell:basic'].invoke(infrastructure, Bosh::Dev::Build.candidate.number)
    end

    def publish
      stemcell = Bosh::Stemcell::Stemcell.new(stemcell_filename)

      if infrastructure == 'aws'
        light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell)
        light_stemcell.write_archive
        light_stemcell_stemcell = Bosh::Stemcell::Stemcell.new(light_stemcell.path)

        Pipeline.new.publish_stemcell(light_stemcell_stemcell)
      end

      Pipeline.new.publish_stemcell(stemcell)
    end

    private

    def stemcell_filename
      @stemcell_filename ||=
        Dir.glob("#{directory}/work/work/*.tgz").first # see: stemcell_builder/stages/stemcell/apply.sh:48
    end
  end
end
