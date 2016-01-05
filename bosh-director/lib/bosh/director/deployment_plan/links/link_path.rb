module Bosh::Director
  module DeploymentPlan
    class LinkPath < Struct.new(:deployment, :job, :template, :name, :path)

      def self.parse(path)
        from_where = path['from']
        parts = from_where.split('.') # the string might be formatted like 'deployment.link_name'
        link_name = parts.shift
        link_path = nil

        if parts.size >= 1  # We have a deployment.
          deployment_name = link_name
          link_name = parts.shift
          if parts.size >= 1
            raise "From string #{from_where} is poorly formated. It should look like 'link_name' or 'deployment_name.link_name'"
          end

          deployment_model = nil

          Models::Deployment.each do |dep|
            if dep.name == deployment_name
              deployment_model = dep
              break
            end
          end

          if deployment_model != nil
            link_path = self.get_link_path_fom_deployment(deployment_model, link_name)
          else
            raise "Can't find deployment #{deployment_name}"
          end
        else  # we'll have to find the deployment ourselves.
          link_path = self.search_deployments_for_link_path(link_name)
        end

        new(link_path[:deployment], link_path[:job], link_path[:template], link_name, "#{link_path[:deployment]}.#{link_path[:job]}.#{link_path[:template]}.#{link_name}")
      end

      def to_s
        "#{deployment}.#{job}.#{template}.#{name}"
      end

      private

      def self.get_link_path_fom_deployment(deployment, name)
        link_path = self.find_link_path_with_name(deployment, name)
        if link_path != nil
          return link_path
        end
        raise "Can't find link with name: #{name} in deployment #{deployment.name}"
      end

      def self.search_deployments_for_link_path(name)
        Models::ReleaseVersion.each do |release_version|
          release_version.deployments.each do |deployment|
            link_path = self.find_link_path_with_name(deployment, name)
            if link_path != nil
              return link_path
            end
          end
        end
        raise "Can't find link with name #{name} in any deployment"
      end

      def self.find_link_path_with_name(deployment, name)
        deployment_link_spec = JSON.parse(deployment.link_spec_json)

        deployment_link_spec.keys.each do |job|
          deployment_link_spec[job].keys.each do |template|
            deployment_link_spec[job][template].keys.each do |link|
              if link == name
                return {:deployment => deployment.name, :job => job, :template => template, :name => name}
              end
            end
          end
        end
        return nil
      end

    end
  end
end