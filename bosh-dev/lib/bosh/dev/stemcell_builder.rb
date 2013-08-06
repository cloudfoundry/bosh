require 'bosh/dev/build'

module Bosh::Dev
  class StemcellBuilder
    def initialize(environment, candidate = Bosh::Dev::Build.candidate)
      @candidate = candidate
      @environment = environment
      ENV['BUILD_PATH'] = environment.build_path
      ENV['WORK_PATH'] = environment.work_path
    end

    def build
      environment.sanitize

      case environment.stemcell_type
        when 'micro'
          micro_task
        when 'basic'
          basic_task
      end

      stemcell_path!
    end

    def stemcell_path
      name = case environment.stemcell_type
               when 'micro'
                 'micro-bosh-stemcell'
               when 'basic'
                 'bosh-stemcell'
             end

      infrastructure = environment.infrastructure == 'openstack' ? 'openstack-kvm' : environment.infrastructure

      File.join(environment.work_path, 'work', "#{name}-#{infrastructure}-#{candidate.number}.tgz")
    end

    private

    attr_reader :candidate, :environment

    def micro_task
      bosh_release_path = candidate.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, environment.infrastructure, candidate.number)
    end

    def basic_task
      Rake::Task['stemcell:basic'].invoke(environment.infrastructure, candidate.number)
    end

    def stemcell_path!
      File.exist?(stemcell_path) or raise "#{stemcell_path} does not exist"

      stemcell_path
    end
  end
end
