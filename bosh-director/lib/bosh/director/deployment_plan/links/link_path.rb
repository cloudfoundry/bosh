module Bosh::Director
  module DeploymentPlan
    class LinkPath < Struct.new(:deployment, :job, :template, :name, :path)

      def self.parse(path)
        from_where = path['from']
        parts = from_where.split('.') # the string might be formatted like 'deployment.link_name'
        name = parts.shift

        if parts.size >= 1  # We have a deployment.
          deployment = name
          name = parts.shift

          deployment_model = Models::Deployment.find {|d| d.name = deployment}
          if deployment_model != nil
            link_path = self.get_link_path_from_deployment(deployment_model, name)
          else
            raise "Can't find deployment #{deployment}"
          end
        else  # we'll have to find the deployment ourselves.
          link_path = self.search_deployments_for_link_path(name)
        end

        new(link_path.deployment, link_path.job, link_path.template, name, "#{link_path.deployment}.#{link_path.job}.#{link_path.template}.#{name}")
      end

      def to_s
        "#{deployment}.#{job}.#{template}.#{name}"
      end

      private

      def self.get_link_path_from_deployment(deployment, name)
        link_path = self.find_link_path_with_name(deployment, name)
        if link_path != nil
          return link_path
        else
          raise "Can't find link with name: #{link_name} in deployment #{deployment_name}"
        end
      end

      def self.search_deployments_for_link_path(name)
        Models::ReleaseVersion.each do |release_version|
          if release_version.release_id == release.id
            release_version.deployments.each do |deployment|
              link_path = self.find_link_path_with_name(deployment, name)
              if link_path != nil
                return link_path
              end
            end
            raise "Can't find link with name #{link_name} in any deployment"
          end
        end
      end

      def self.find_link_path_with_name(deployment, name)
        deployment_link_spec = JSON.parse(deployment.link_spec_json)

        deployment_link_spec.keys.each do |job|
          deployment_link_spec[job].keys.each do |template|
            deployment_link_spec[job][template].keys.each do |link|
              if link == name
                return {:deployment => deployment.name, :job => result.job, :template => result.template, :name => name}
              end
            end
          end
        end
        return nil
      end

    end
  end
end