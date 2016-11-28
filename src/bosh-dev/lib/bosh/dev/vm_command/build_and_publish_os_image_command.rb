require 'securerandom'

module Bosh::Dev
  module VmCommand
    class BuildAndPublishOsImageCommand
      def initialize(env, options)
        @env = env
        @options = options
      end

      def to_s
        [
          'set -eu',
          'cd /bosh',
          exports.join("\n"),
          "bundle exec rake stemcell:build_os_image[#{build_task_args}]",
          "bundle exec rake stemcell:upload_os_image[#{publish_task_args}]"
        ].join("\n")
      end

      private

      attr_reader :env,
                  :options

      def filename
        @filename ||= "/tmp/#{SecureRandom.uuid}"
      end

      def build_task_args
        [
          options[:operating_system_name],
          options[:operating_system_version],
          filename,
        ].join(',')
      end

      def publish_task_args
        [
          filename,
          options[:os_image_s3_bucket_name],
          options[:os_image_s3_key],
        ].join(',')
      end

      def exports
        %w[
          BOSH_AWS_ACCESS_KEY_ID
          BOSH_AWS_SECRET_ACCESS_KEY
        ].map do |env_var|
          "export #{env_var}='#{env.fetch(env_var)}'"
        end
      end
    end
  end
end
