module Bosh::Director
  module DeploymentPlan
    class LinkPath
      attr_reader :deployment_plan_name, :deployment, :job, :template, :name, :path, :skip, :manual_spec

      def initialize(deployment_plan_name, instance_groups, instance_group_name, job_name)
        @deployment_plan_name = deployment_plan_name
        @instance_groups = instance_groups
        @consumes_job_name = instance_group_name
        @consumes_template_name = job_name
        @deployment = nil
        @job = nil
        @template = nil
        @name = nil
        @path = nil
        @skip = false
        @manual_spec = nil
        @disk = false
      end

      def parse(link_info)
        # in case the link was explicitly set to the string 'nil', do not add it
        # to the link paths, even if the link provider exist, since the user intent
        # was explicitly set to not consume any link

        if link_info['skip_link'] && link_info['skip_link'] == true
          @skip = true
          return
        end

        if link_info.has_key?('from')
          link_path = fulfill_explicit_link(link_info)
        elsif ( link_info.has_key?('instances') ||
                link_info.has_key?('properties') ||
                link_info.has_key?('address') )
          @manual_spec = {}
          @manual_spec['deployment_name'] = @deployment_plan_name
          @manual_spec['instances'] = link_info['instances']
          @manual_spec['properties'] = link_info['properties']
          @manual_spec['address'] = link_info['address']
          return
        else
          link_path = fulfill_implicit_link(link_info)
        end
        if link_path != nil
          @deployment, @job, @template, @name, @disk = link_path.values_at(:deployment, :job, :template, :name, :disk)
          @path = "#{link_path[:deployment]}.#{link_path[:job]}.#{link_path[:template]}.#{link_path[:name]}"
        else
          @skip = true
        end
      end

      def disk?
        @disk
      end

      def to_s
        "#{@deployment}.#{@job}.#{@template}.#{@name}"
      end

      private

      def fulfill_implicit_link(link_info)
        link_type = link_info['type']
        link_network = link_info['network']
        found_link_paths = []

        @instance_groups.each do |provides_instance_group|
          if instance_group_has_link_network(provides_instance_group, link_network)
            provides_instance_group.jobs.each do |provides_job|
              if provides_job.link_infos.has_key?(provides_instance_group.name) && provides_job.link_infos[provides_instance_group.name].has_key?('provides')
                matching_links = provides_job.link_infos[provides_instance_group.name]['provides'].select { |_,v| v['type'] == link_type }
                matching_links.each do |_, matching_link_values|
                  link_name = matching_link_values.has_key?('as') ? matching_link_values['as'] : matching_link_values['name']
                  found_link_paths.push({:deployment => @deployment_plan_name, :job => provides_instance_group.name, :template => provides_job.name, :name => link_name})
                end
              end
            end
          end
        end

        if found_link_paths.size == 1
          return found_link_paths[0]
        elsif found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            all_link_paths = all_link_paths + "\n   #{link_path[:deployment]}.#{link_path[:job]}.#{link_path[:template]}.#{link_path[:name]}"
          end
          raise "Multiple instance groups provide links of type '#{link_type}'. Cannot decide which one to use for instance group '#{@consumes_job_name}'.#{all_link_paths}"
        else
          # Only raise an exception if no linkpath was found, and the link is not optional
          if !link_info['optional']
             raise "Can't find link with type '#{link_type}' for job '#{@consumes_job_name}' in deployment '#{@deployment_plan_name}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}"
          end
        end
      end

      def fulfill_explicit_link(link_info)
        from_name = link_info['from']
        link_network = link_info['network']
        deployment_name = link_info['deployment']

        if !deployment_name.nil?
          if deployment_name == @deployment_plan_name
            link_path = get_link_path_from_deployment_plan(from_name, link_network)
          else
            link_path = find_deployment_and_get_link_path(deployment_name, from_name, link_network)
          end
        else  # given no deployment name
          link_path = get_link_path_from_deployment_plan(from_name, link_network)   # search the jobs for the current deployment for a provides
        end

        link_path[:name] = from_name
        return link_path
      end

      def get_link_path_from_deployment_plan(name, link_network)
        found_link_paths = []
        @instance_groups.each do |instance_group|
          if instance_group_has_link_network(instance_group, link_network)
            instance_group.jobs.each do |job|
              job.provides_links_for_instance_group_name(instance_group.name).each do |_, source|
                link_name = source.has_key?('as') ? source['as'] : source['name']
                if link_name == name
                  found_link_paths.push({:deployment => @deployment_plan_name, :job => instance_group.name, :template => job.name, :name => source['name'], :as => source['as']})
                end
              end
            end
          end

          instance_group.persistent_disk_collection.non_managed_disks.each do |disk|
            if disk.name == name
              found_link_paths.push(
                {
                  :disk => true,
                  :deployment => @deployment_plan_name,
                  :job => instance_group.name,
                  :template => nil,
                  :name => name,
                  :as => nil
                }
              )
            end
          end

        end
        if found_link_paths.size == 1
          return {
            :deployment => found_link_paths[0][:deployment],
            :job => found_link_paths[0][:job],
            :template => found_link_paths[0][:template],
            :name => found_link_paths[0][:as].nil? ? found_link_paths[0][:name] : found_link_paths[0][:as],
            disk: found_link_paths[0][:disk]
          }
        elsif found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            all_link_paths = all_link_paths + "\n   #{link_path[:name]}#{" aliased as '#{link_path[:as]}'" unless link_path[:as].nil?} (job: #{link_path[:template]}, instance group: #{link_path[:job]})"
          end
          raise "Cannot resolve ambiguous link '#{name}' (job: #{@consumes_template_name}, instance group: #{@consumes_job_name}). All of these match: #{all_link_paths}"
        else
          raise "Can't resolve link '#{name}' in instance group '#{@consumes_job_name}' on job '#{@consumes_template_name}' in deployment '#{@deployment_plan_name}'#{" and network '#{link_network}'" unless link_network.to_s.empty?}."
        end
      end

      def instance_group_has_link_network(instance_group, link_network)
        !link_network || instance_group.has_network?(link_network)
      end

      def find_deployment_and_get_link_path(deployment_name, name, link_network)
        deployment_model = Models::Deployment.find(name: deployment_name)
        if !deployment_model
          raise "Can't find deployment #{deployment_name}"
        end

        # get the link path from that deployment
        find_link_path_with_name(deployment_model, name, link_network)
    end

      def find_link_path_with_name(deployment, name, link_network)
        found_link_paths = []

        Models::LinkProvider.where(deployment: deployment, name: name).each do |lp|
          content = JSON.parse(lp.content)
          if lp.shared && (!link_network || (content['networks'].include? link_network))
            #TODO extract instance_group name from top level element from `link_provider`
            found_link_paths.push({:deployment => deployment.name, :job => lp.instance_group, :template => lp.owner_object_name, :name => name})
          end
        end
        if found_link_paths.size == 1
          return found_link_paths[0]
        elsif found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            all_link_paths = all_link_paths + "\n   #{link_path[:deployment]}.#{link_path[:job]}.#{link_path[:template]}.#{link_path[:name]}"
          end
          link_str = "#{@deployment_plan_name}.#{@consumes_job_name}.#{@consumes_template_name}.#{name}"
          raise "Cannot resolve ambiguous link '#{link_str}' in deployment #{deployment.name}:#{all_link_paths}"
        else
          raise "Can't resolve link '#{name}' in instance group '#{@consumes_job_name}' on job '#{@consumes_template_name}' in deployment '#{@deployment_plan_name}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}. Please make sure the link was provided and shared."
        end
      end

    end
  end
end
