module Bosh::Dev
  class StemcellVm
    def initialize(options, env, build_environment)
      @vm_name = options.fetch(:vm_name)
      @infrastructure_name = options.fetch(:infrastructure_name)
      @operating_system_name = options.fetch(:operating_system_name)
      @operating_system_version = options.fetch(:operating_system_version)
      @agent_name = options.fetch(:agent_name)
      @os_image_s3_bucket_name = options.fetch(:os_image_s3_bucket_name)
      @os_image_s3_key = options.fetch(:os_image_s3_key)
      @env = env
      @build_environment = build_environment
    end

    def publish
      Rake::FileUtilsExt.sh <<-BASH
        set -eu

        cd bosh-stemcell
        [ -e .vagrant/machines/remote/aws/id ] && vagrant destroy #{vm_name} --force
        vagrant up #{vm_name} --provider #{provider}
        [ -e .vagrant/machines/remote/aws/id ] && cat .vagrant/machines/remote/aws/id

        vagrant ssh -c "
          bash -l -c '
            set -eu
            cd /bosh

            #{exports.join("\n            ")}

            bundle exec rake stemcell:build[#{build_task_args}]
            bundle exec rake ci:publish_stemcell[#{stemcell_path}]
          '
        " #{vm_name}
      BASH
    ensure
      Rake::FileUtilsExt.sh <<-BASH
        set -eu
        cd bosh-stemcell
        vagrant destroy #{vm_name} --force
      BASH
    end

    def stemcell_path
      build_environment.stemcell_file
    end

    def build_task_args
      "#{infrastructure_name},#{operating_system_name},#{operating_system_version},#{agent_name},#{os_image_s3_bucket_name},#{os_image_s3_key}"
    end

    private

    attr_reader :vm_name,
                :infrastructure_name,
                :operating_system_name,
                :operating_system_version,
                :agent_name,
                :os_image_s3_bucket_name,
                :os_image_s3_key,
                :env,
                :build_environment

    def provider
      case vm_name
        when 'remote' then 'aws'
        when 'local' then 'virtualbox'
        else raise "vm_name must be 'local' or 'remote'"
      end
    end

    def exports
      exports = []

      exports += %w[
        CANDIDATE_BUILD_NUMBER
        BOSH_AWS_ACCESS_KEY_ID
        BOSH_AWS_SECRET_ACCESS_KEY
      ].map do |env_var|
        "export #{env_var}='#{env.fetch(env_var)}'"
      end

      exports += %w[
        UBUNTU_ISO
      ].map do |env_var|
        "export #{env_var}='#{env.fetch(env_var)}'" if env.has_key?(env_var)
      end.compact

      exports
    end
  end
end
