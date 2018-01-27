module Bosh::Director
  module DeploymentPlan
    class LinkPath
      attr_reader :deployment_plan_name, :deployment, :instance_group, :job, :name, :path, :skip, :manual_spec

      def initialize(deployment_plan_name, instance_groups, instance_group_name, job_name)
        @deployment_plan_name = deployment_plan_name
        @instance_groups = instance_groups
        @consumes_instance_group_name = instance_group_name
        @consumes_job_name = job_name
        @deployment = nil
        @instance_group = nil
        @job = nil
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

        if link_info.key?('from')
          link_path = fulfill_explicit_link(link_info)
        elsif link_info.key?('instances') ||
              link_info.key?('properties') ||
              link_info.key?('address')
          @manual_spec = {}
          @manual_spec['deployment_name'] = @deployment_plan_name
          @manual_spec['instances'] = link_info['instances']
          @manual_spec['properties'] = link_info['properties']
          @manual_spec['address'] = link_info['address']
          return
        else
          link_path = fulfill_implicit_link(link_info)
        end
        if !link_path.nil?
          @deployment, @instance_group, @job, @name, @disk = link_path.values_at(:deployment, :instance_group, :job, :name, :disk)
          @path = "#{link_path[:deployment]}.#{link_path[:instance_group]}.#{link_path[:job]}.#{link_path[:name]}"
        else
          @skip = true
        end
      end

      def disk?
        @disk
      end

      def owner
        disk? ? @instance_group : @job
      end

      def to_s
        "#{@deployment}.#{@instance_group}.#{@job}.#{@name}"
      end

      private

      def fulfill_implicit_link(link_info)
        link_type = link_info['type']
        link_network = link_info['network']
        found_link_paths = []

        @instance_groups.each do |provides_instance_group|
          next unless instance_group_has_link_network(provides_instance_group, link_network)

          provides_instance_group.jobs.each do |provides_job|
            next unless provides_job.link_infos.key?(provides_instance_group.name) &&
                        provides_job.link_infos[provides_instance_group.name].key?('provides')

            matching_links = provides_job.link_infos[provides_instance_group.name]['provides'].select do |_, v|
              v['type'] == link_type
            end

            matching_links.each_value do |matching_link_values|
              link_name = matching_link_values.key?('as') ? matching_link_values['as'] : matching_link_values['name']
              found_link_paths.push(
                deployment: @deployment_plan_name,
                instance_group: provides_instance_group.name,
                job: provides_job.name,
                name: link_name,
              )
            end
          end
        end

        return found_link_paths[0] if found_link_paths.size == 1

        if found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            deployment_path = link_path[:deployment]
            instance_group_path = link_path[:instance_group]
            job_path = link_path[:job]
            name_path = link_path[:name]

            all_link_paths += "\n   #{deployment_path}.#{instance_group_path}.#{job_path}.#{name_path}"
          end
          raise "Multiple instance groups provide links of type '#{link_type}'. "\
                "Cannot decide which one to use for instance group '#{@consumes_instance_group_name}'.#{all_link_paths}"
        else
          # Only raise an exception if no linkpath was found, and the link is not optional
          unless link_info['optional']
            error_string = "Can't find link with type '#{link_type}' for instance_group '#{@consumes_instance_group_name}' "\
                  "in deployment '#{@deployment_plan_name}'"
            error_string += " and network '#{link_network}'" unless link_network.to_s.empty?
            raise error_string
          end
        end
      end

      def fulfill_explicit_link(link_info)
        from_name = link_info['from']
        link_network = link_info['network']
        deployment_name = link_info['deployment']

        link_path = if deployment_name.nil?
                      # search the jobs for the current deployment for a provides
                      get_link_path_from_deployment_plan(from_name, link_network)
                    elsif deployment_name == @deployment_plan_name
                      get_link_path_from_deployment_plan(from_name, link_network)
                    else
                      find_deployment_and_get_link_path(deployment_name, from_name, link_network)
                    end

        link_path[:name] = from_name
        link_path
      end

      def get_link_path_from_deployment_plan(name, link_network)
        found_link_paths = []
        @instance_groups.each do |instance_group|
          if instance_group_has_link_network(instance_group, link_network)
            instance_group.jobs.each do |job|
              job.provides_links_for_instance_group_name(instance_group.name).each do |_, source|
                link_name = source.key?('as') ? source['as'] : source['name']
                next if link_name != name

                found_link_paths.push(
                  deployment: @deployment_plan_name,
                  instance_group: instance_group.name,
                  job: job.name,
                  name: source['name'],
                  as: source['as'],
                )
              end
            end
          end

          instance_group.persistent_disk_collection.non_managed_disks.each do |disk|
            next unless disk.name == name
            found_link_paths.push(
              disk: true,
              deployment: @deployment_plan_name,
              instance_group: instance_group.name,
              job: nil,
              name: name,
              as: nil,
            )
          end
        end
        if found_link_paths.size == 1
          return {
            deployment: found_link_paths[0][:deployment],
            instance_group: found_link_paths[0][:instance_group],
            job: found_link_paths[0][:job],
            name: found_link_paths[0][:as].nil? ? found_link_paths[0][:name] : found_link_paths[0][:as],
            disk: found_link_paths[0][:disk],
          }
        elsif found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            name_path = link_path[:name]
            as_path = link_path[:as]
            job_path = link_path[:job]
            instance_group_path = link_path[:instance_group]

            all_link_paths += "\n   #{name_path}"
            all_link_paths += " aliased as '#{as_path}'" unless as_path.nil?
            all_link_paths += " (job: #{job_path}, instance group: #{instance_group_path})"
          end
          raise "Cannot resolve ambiguous link '#{name}' (job: #{@consumes_job_name}, "\
                "instance group: #{@consumes_instance_group_name}). All of these match: #{all_link_paths}"
        else
          error_string = "Can't resolve link '#{name}' in instance group '#{@consumes_instance_group_name}' "\
                         "on job '#{@consumes_job_name}' in deployment '#{@deployment_plan_name}'"
          error_string += " and network '#{link_network}'" unless link_network.to_s.empty?
          raise error_string + '.'
        end
      end

      def instance_group_has_link_network(instance_group, link_network)
        !link_network || instance_group.network_present?(link_network)
      end

      def find_deployment_and_get_link_path(deployment_name, name, link_network)
        deployment_model = Models::Deployment.find(name: deployment_name)
        raise "Can't find deployment #{deployment_name}" unless deployment_model

        # get the link path from that deployment
        find_link_path_with_name(deployment_model, name, link_network)
      end

      def find_link_path_with_name(deployment, name, link_network)
        found_link_paths = []

        Models::LinkProvider.where(deployment: deployment, name: name).each do |lp|
          content = JSON.parse(lp.content)
          next unless lp.shared && (!link_network || (content['networks'].include? link_network))
          # TODO: extract instance_group name from top level element from `link_provider`
          found_link_paths.push(
            deployment: deployment.name,
            instance_group: lp.instance_group,
            job: lp.owner_object_name,
            name: name,
          )
        end

        return found_link_paths[0] if found_link_paths.size == 1

        if found_link_paths.size > 1
          all_link_paths = ''
          found_link_paths.each do |link_path|
            deployment_path = link_path[:deployment]
            instance_group_path = link_path[:instance_group]
            job_path = link_path[:job]
            name_path = link_path[:name]

            all_link_paths += "\n   #{deployment_path}.#{instance_group_path}.#{job_path}.#{name_path}"
          end
          link_str = "#{@deployment_plan_name}.#{@consumes_instance_group_name}.#{@consumes_job_name}.#{name}"
          raise "Cannot resolve ambiguous link '#{link_str}' in deployment #{deployment.name}:#{all_link_paths}"
        else
          error_string = "Can't resolve link '#{name}' in instance group '#{@consumes_instance_group_name}' "\
            "on job '#{@consumes_job_name}' in deployment '#{@deployment_plan_name}'"
          error_string += " and network '#{link_network}'" unless link_network.to_s.empty?
          error_string += '. Please make sure the link was provided and shared'
          raise error_string + '.'
        end
      end
    end
  end
end
