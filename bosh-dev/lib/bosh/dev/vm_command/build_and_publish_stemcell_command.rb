module Bosh::Dev
  module VmCommand
    class BuildAndPublishStemcellCommand
      def initialize(build_environment, env, options)
        @build_environment = build_environment
        @env = env
        @options = options
      end

      def to_s
        [
          'set -eu',
          'cd /bosh',
          exports,
          "bundle exec rake stemcell:build[#{build_task_args}]",
          @build_environment.stemcell_files.map do |stemcell_file|
            "bundle exec rake ci:publish_stemcell[#{stemcell_file},#{options[:publish_s3_bucket_name]}]"
          end
        ].flatten.join("\n")
      end

      private

      attr_reader :build_environment,
                  :env,
                  :options

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

      def build_task_args
        [
          options[:infrastructure_name],
          options[:hypervisor_name],
          options[:operating_system_name],
          options[:operating_system_version],
          options[:agent_name],
          options[:os_image_s3_bucket_name],
          options[:os_image_s3_key],
        ].join(',')
      end
    end
  end
end
