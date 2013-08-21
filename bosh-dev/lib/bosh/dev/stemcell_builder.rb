require 'bosh/dev/build'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_rake_methods'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellBuilder
    def initialize(infrastructure_name, candidate = Bosh::Dev::Build.candidate)
      @stemcell_environment = StemcellEnvironment.new(infrastructure_name: infrastructure_name)
      @infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      @candidate = candidate
      @archive_filename = Bosh::Stemcell::ArchiveFilename.new(candidate.number, infrastructure, 'bosh-stemcell', false)
    end

    def build
      stemcell_environment.sanitize

      build_stemcell

      stemcell_path!
    end

    private

    attr_reader :candidate,
                :archive_filename,
                :infrastructure,
                :stemcell_environment

    def build_stemcell
      stemcell_rake_methods = Bosh::Dev::StemcellRakeMethods.new(stemcell_environment: stemcell_environment,
                                                                 args: {
                                                                   tarball: candidate.download_release,
                                                                   stemcell_version: candidate.number,
                                                                   infrastructure: infrastructure.name,
                                                                   stemcell_tgz: archive_filename.to_s,
                                                                 })

      stemcell_rake_methods.build_stemcell
    end

    def stemcell_path!
      stemcell_path = File.join(stemcell_environment.work_path, 'work', archive_filename.to_s)

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end
  end
end
