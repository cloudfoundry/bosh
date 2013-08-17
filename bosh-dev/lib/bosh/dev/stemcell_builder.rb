require 'bosh/dev/build'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_rake_methods'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellBuilder
    attr_reader :directory, :work_path

    def initialize(infrastructure_name, candidate = Bosh::Dev::Build.candidate)
      @candidate = candidate
      @infrastructure_name = infrastructure_name

      mnt = ENV.fetch('FAKE_MNT', '/mnt')
      @directory = File.join(mnt, 'stemcells', "#{infrastructure_name}")
      @work_path = File.join(directory, 'work')
      @build_path = File.join(directory, 'build')
    end

    def build
      ENV['BUILD_PATH'] = build_path
      ENV['WORK_PATH'] = work_path

      environment = StemcellEnvironment.new(self)
      environment.sanitize

      build_task

      stemcell_path!
    end

    private

    attr_reader :candidate,
                :infrastructure_name,
                :build_path

    def new_style_path
      File.join(work_path, 'work', new_style_name)
    end

    def new_style_name
      infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      Bosh::Stemcell::ArchiveFilename.new(candidate.number, infrastructure, name, false).to_s
    end

    def name
      'bosh-stemcell'
    end

    def build_task
      bosh_release_path = candidate.download_release

      stemcell_rake_methods = Bosh::Dev::StemcellRakeMethods.new(args: {
        tarball: bosh_release_path,
        infrastructure: infrastructure_name,
        stemcell_version: candidate.number,
        stemcell_tgz: new_style_name,
      })

      stemcell_rake_methods.build_basic_stemcell
    end

    def stemcell_path!
      File.exist?(new_style_path) || raise("#{new_style_path} does not exist")

      new_style_path
    end
  end
end
