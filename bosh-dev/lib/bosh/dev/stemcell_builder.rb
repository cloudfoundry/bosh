require 'bosh/dev/build'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_rake_methods'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellBuilder
    attr_reader :directory, :work_path

    def initialize(infrastructure_name, candidate = Bosh::Dev::Build.candidate)
      @candidate = candidate
      @infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      @archive_filename = Bosh::Stemcell::ArchiveFilename.new(candidate.number, infrastructure, 'bosh-stemcell', false)
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

      build_stemcell

      stemcell_path!
    end

    private

    attr_reader :candidate,
                :archive_filename,
                :infrastructure,
                :build_path

    def build_stemcell
      bosh_release_path = candidate.download_release

      stemcell_rake_methods = Bosh::Dev::StemcellRakeMethods.new(args: {
        tarball: bosh_release_path,
        infrastructure: infrastructure.name,
        stemcell_version: candidate.number,
        stemcell_tgz: archive_filename.to_s,
      })

      stemcell_rake_methods.build_stemcell
    end

    def stemcell_path!
      stemcell_path = File.join(work_path, 'work', archive_filename.to_s)

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end
  end
end
