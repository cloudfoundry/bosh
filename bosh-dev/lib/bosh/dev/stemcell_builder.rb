require 'bosh/dev/build'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  class StemcellBuilder
    attr_reader :directory, :work_path

    def initialize(stemcell_type, infrastructure, candidate = Bosh::Dev::Build.candidate)
      @candidate = candidate
      @stemcell_type = stemcell_type
      @infrastructure = infrastructure

      mnt = ENV.fetch('FAKE_MNT', '/mnt')
      @directory = File.join(mnt, 'stemcells', "#{infrastructure}-#{stemcell_type}")
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

    def stemcell_path
      name = case stemcell_type
               when 'micro'
                 'micro-bosh-stemcell'
               when 'basic'
                 'bosh-stemcell'
             end

      infrastructure_name = infrastructure == 'openstack' ? 'openstack-kvm' : infrastructure

      File.join(work_path, 'work', "#{name}-#{infrastructure_name}-#{candidate.number}.tgz")
    end

    private

    attr_reader :candidate,
                :stemcell_type,
                :infrastructure,
                :build_path

    def micro_task
      bosh_release_path = candidate.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, infrastructure, candidate.number)
    end

    def basic_task
      Rake::Task['stemcell:basic'].invoke(infrastructure, candidate.number)
    end

    def stemcell_path!
      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end
  end
end
