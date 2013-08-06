require 'bosh/dev/build'

module Bosh::Dev
  class StemcellBuilder
    def initialize(environment, build = Bosh::Dev::Build.candidate)
      @build = build
      @environment = environment
      ENV['BUILD_PATH'] = environment.build_path
      ENV['WORK_PATH'] = environment.work_path
      ENV['STEMCELL_VERSION'] = environment.stemcell_version
    end

    def micro
      environment.sanitize
      bosh_release_path = build.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, environment.infrastructure, build.number)

      stemcell_path!
    end

    def basic
      environment.sanitize
      Rake::Task['stemcell:basic'].invoke(environment.infrastructure, build.number)

      stemcell_path!
    end


    def stemcell_path
      name = environment.stemcell_type == 'micro' ? 'micro-bosh-stemcell' : 'bosh-stemcell'
      infrastructure = environment.infrastructure == 'openstack' ? 'openstack-kvm' : environment.infrastructure

      File.join(environment.work_path, 'work', "#{name}-#{infrastructure}-#{build.number}.tgz")
    end

    private

    attr_reader :build, :environment

    def stemcell_path!
      File.exist?(stemcell_path) or raise "#{stemcell_path} does not exist"

      stemcell_path
    end
  end
end
