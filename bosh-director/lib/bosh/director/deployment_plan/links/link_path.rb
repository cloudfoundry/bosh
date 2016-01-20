module Bosh::Director
  module DeploymentPlan
    class LinkPath < Struct.new(:deployment, :job, :template, :name, :path)

      def self.parse(deployment_plan, link_info)
        if link_info.has_key?("from")
          link_path = self.fulfill_explicit_link(deployment_plan, link_info)
        else
          link_path = self.fulfill_implicit_link(deployment_plan, link_info)
        end
        new(link_path[:deployment], link_path[:job], link_path[:template], link_path[:name], "#{link_path[:deployment]}.#{link_path[:job]}.#{link_path[:template]}.#{link_path[:name]}")
      end

      def to_s
        "#{deployment}.#{job}.#{template}.#{name}"
      end

      private

      def self.fulfill_implicit_link(deployment_plan, link_info)
        link_type = link_info["type"]
        link_path_found = nil
        deployment_plan.jobs.each do |provides_job|
          provides_job.templates.each do |provides_template|
            if provides_template.link_infos.has_key?(provides_job.name) && provides_template.link_infos[provides_job.name].has_key?('provides')
              matching_links = provides_template.link_infos[provides_job.name]["provides"].select { |k,v| v["type"] == link_type }
              if matching_links.size > 0
                if link_path_found.nil?
                  link_path_found = {:deployment => deployment_plan.name, :job => provides_job.name, :template => provides_template.name, :name => matching_links.values()[0]["name"]}
                else
                  raise "Multiple provide links have type #{link_type}. Can not make implicit link"
                end
              end
            end
          end
        end
        if link_path_found.nil?
          raise "Can't find link with type: #{link_type} in deployment #{deployment_plan.name}"
        end
        return link_path_found
      end

      def self.fulfill_explicit_link(deployment_plan, link_info)
        from_where = link_info['from']
        parts = from_where.split('.') # the string might be formatted like 'deployment.link_name'
        from_name = parts.shift

        if parts.size >= 1  # given a deployment name
          deployment_name = from_name
          from_name = parts.shift
          if parts.size >= 1
            raise "From string #{from_where} is poorly formatted. It should look like 'link_name' or 'deployment_name.link_name'"
          end

          if deployment_name == deployment_plan.name
            link_path = self.get_link_path_from_deployment_plan(deployment_plan, from_name)
          else
            link_path = self.find_deployment_and_get_link_path(deployment_name, from_name)
          end
        else  # given no deployment name
          link_path = self.get_link_path_from_deployment_plan(deployment_plan, from_name)   # search the jobs for the current deployment for a provides
        end
        link_path[:name] = from_name
        return link_path
      end

      def self.get_link_path_from_deployment_plan(deployment_plan, name)
        link_path_found = nil
        deployment_plan.jobs.each do |job|
          job.templates.each do |template|
            if template.link_infos.has_key?(job.name) && template.link_infos[job.name].has_key?('provides')
              template.link_infos[job.name]['provides'].to_a.each do |provides_name, source|
                link_name = source.has_key?("as") ? source['as'] : source['name']
                if link_name == name
                  if link_path_found.nil?
                    link_path_found = {:deployment => deployment_plan.name, :job => job.name, :template => template.name, :name => name}
                  else
                    raise "Multiple links found with name: #{name} in deployment #{deployment_plan.name}"
                  end
                end
              end
            end
          end
        end
        if link_path_found.nil?
          raise "Can't find link with name: #{name} in deployment #{deployment_plan.name}"
        end
        return link_path_found
      end

      def self.find_deployment_and_get_link_path(deployment_name, name)
        deployment_model = Models::Deployment.where(:name => deployment_name)

        # get the link path from that deployment
        if deployment_model.count != 0
          return self.get_link_path_fom_deployment(deployment_model.first, name)
        else
          raise "Can't find deployment #{deployment_name}"
        end
      end

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
        deployment_link_spec = deployment.link_spec
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