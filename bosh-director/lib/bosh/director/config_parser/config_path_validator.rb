module Bosh::Director::ConfigServer
  class ConfigPathValidator

    class << self
      def validate(path)
        global_prop?(path) || instant_group_prop?(path) ||
          job_prop?(path) || env_prop?(path) || link_prop?(path)
      end

      private

      def global_prop?(path)
        path[0] == 'properties'
      end

      def instant_group_prop?(path)
        if_instance_group?(path) && path[2] == 'properties'
      end

      def job_prop?(path)
        if_job?(path) && path[4] == 'properties'
      end

      def env_prop?(path)
        path[0] == 'resource_pools' && path[1].is_a?(Integer) && path[2] == 'env'
      end

      def link_prop?(path)
        if_job?(path) && path[4] == 'consumes' && path[5].is_a?(String) && path[6] == 'properties'
      end

      def if_job?(path)
        path[0] == 'instance_groups' && path[1].is_a?(Integer) &&
          path[2] == 'jobs' && path[3].is_a?(Integer)
      end

      def if_instance_group?(path)
        path[0] == 'instance_groups' && path[1].is_a?(Integer)
      end
    end

  end
end