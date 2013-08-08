require 'bosh/dev/build'
require 'bosh/dev/stemcell_environment'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellBuilder
    attr_reader :directory, :work_path

    def initialize(stemcell_type, infrastructure_name, candidate = Bosh::Dev::Build.candidate)
      @candidate = candidate
      @stemcell_type = stemcell_type
      @infrastructure_name = infrastructure_name

      mnt = ENV.fetch('FAKE_MNT', '/mnt')
      @directory = File.join(mnt, 'stemcells', "#{infrastructure_name}-#{stemcell_type}")
      @work_path = File.join(directory, 'work')
      @build_path = File.join(directory, 'build')
    end

    def build
      ENV['BUILD_PATH'] = build_path
      ENV['WORK_PATH'] = work_path

      environment = StemcellEnvironment.new(self)
      environment.sanitize

      case stemcell_type
        when 'micro'
          micro_task
        when 'basic'
          basic_task
      end

      stemcell_path!
    end

    private

    attr_reader :candidate,
                :stemcell_type,
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
      case stemcell_type
        when 'micro'
          'micro-bosh-stemcell'
        when 'basic'
          'bosh-stemcell'
      end
    end

    def micro_task
      bosh_release_path = candidate.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, infrastructure_name, candidate.number, new_style_name)
    end

    def basic_task
      Rake::Task['stemcell:basic'].invoke(infrastructure_name, candidate.number, new_style_name)
    end

    def stemcell_path!
      File.exist?(new_style_path) || raise("#{new_style_path} does not exist")

      new_style_path
    end
  end
end
