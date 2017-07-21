module Bosh::Director
  module DeploymentPlan
    class InstanceSpec
      def self.create_empty
        EmptyInstanceSpec.new
      end

      def self.create_from_database(spec, instance)
        new(spec, instance)
      end

      def self.create_from_instance_plan(instance_plan)
        instance = instance_plan.instance
        deployment_name = instance.deployment_model.name
        instance_group = instance_plan.desired_instance.instance_group
        instance_plan = instance_plan
        powerdns_manager = PowerDnsManagerProvider.create

        spec = {
          'deployment' => deployment_name,
          'job' => instance_group.spec,
          'index' => instance.index,
          'bootstrap' => instance.bootstrap?,
          'lifecycle' => instance_group.lifecycle,
          'name' => instance.job_name,
          'id' => instance.uuid,
          'az' => instance.availability_zone_name,
          'networks' => instance_plan.network_settings_hash,
          'vm_type' => instance_group.vm_type.spec,
          'stemcell' => instance_group.stemcell.spec,
          'env' => instance_group.env.spec,
          'packages' => instance_group.package_spec,
          'properties' => instance_group.properties,
          'properties_need_filtering' => true,
          'dns_domain_name' => powerdns_manager.root_domain,
          'links' => instance_group.resolved_links,
          'address' => instance_plan.network_settings.network_address,
          'update' => instance_group.update_spec
        }

        disk_spec = instance_group.persistent_disk_collection.generate_spec

        spec.merge!(disk_spec)

        new(spec, instance)
      end

      def initialize(full_spec, instance)
        @full_spec = full_spec
        @instance = instance
        @variables_interpolator = ConfigServer::VariablesInterpolator.new
      end

      def as_template_spec
        TemplateSpec.new(full_spec, @variables_interpolator, @instance.desired_variable_set).spec
      end

      def as_apply_spec
        ApplySpec.new(full_spec).spec
      end

      def full_spec
        # re-generate spec with rendered templates info
        # since job renderer sets it directly on instance
        spec = @full_spec

        if @instance.template_hashes
          spec['template_hashes'] = @instance.template_hashes
        end

        if @instance.rendered_templates_archive
          spec['rendered_templates_archive'] = @instance.rendered_templates_archive.spec
        end

        if @instance.configuration_hash
          spec['configuration_hash'] = @instance.configuration_hash
        end

        spec
      end
    end

    private

    class EmptyInstanceSpec < InstanceSpec
      def initialize
      end

      def full_spec
        {}
      end
    end

    class TemplateSpec
      def initialize(full_spec, variables_interpolator, variable_set)
        @full_spec = full_spec
        @variables_interpolator = variables_interpolator
        @variable_set = variable_set
      end

      def spec
        keys = [
          'deployment',
          'job',
          'index',
          'bootstrap',
          'name',
          'id',
          'az',
          'networks',
          'properties_need_filtering',
          'dns_domain_name',
          'persistent_disk',
          'address',
          'ip'
        ]

        whitelisted_link_spec_keys = [
          'instances',
          'properties'
        ]

        template_hash = @full_spec.select {|k,v| keys.include?(k) }

        template_hash['properties'] =  @variables_interpolator.interpolate_template_spec_properties(@full_spec['properties'], @full_spec['deployment'], @variable_set)

        template_hash['links'] = {}
        links_hash = @full_spec.fetch('links', {})
        links_hash.each do |job_name, links|
          template_hash['links'][job_name] ||= {}
          interpolated_links_spec = @variables_interpolator.interpolate_link_spec_properties(links, @variable_set)

          interpolated_links_spec.each do |link_name, link_spec|
            template_hash['links'][job_name][link_name] = link_spec.select {|k,v| whitelisted_link_spec_keys.include?(k) }
          end
        end

        networks_hash = template_hash['networks']

        ip = nil
        modified_networks_hash = networks_hash.each_pair do |network_name, network_settings|
          if @full_spec['job'] != nil
            settings_with_dns = network_settings.merge({'dns_record_name' => DnsNameGenerator.dns_record_name(@full_spec['index'], @full_spec['job']['name'], network_name, @full_spec['deployment'], @full_spec['dns_domain_name'])})
            networks_hash[network_name] = settings_with_dns
          end

          defaults = network_settings['default'] || []

          if defaults.include?('addressable') || (!ip && defaults.include?('gateway'))
            ip = network_settings['ip']
          end

          if network_settings['type'] == 'dynamic'
            # Templates may get rendered before we know dynamic IPs from the Agent.
            # Use valid IPs so that templates don't have to write conditionals around nil values.
            networks_hash[network_name]['ip'] ||= '127.0.0.1'
            networks_hash[network_name]['netmask'] ||= '127.0.0.1'
            networks_hash[network_name]['gateway'] ||= '127.0.0.1'
          end
        end

        template_hash.merge({
        'ip' => ip,
        'resource_pool' => @full_spec['vm_type']['name'],
        'networks' => modified_networks_hash
        })
      end
    end

    class ApplySpec
      def initialize(full_spec)
        @full_spec = full_spec
      end

      def spec
        keys = [
          'deployment',
          'job',
          'index',
          'name',
          'id',
          'az',
          'networks',
          'packages',
          'dns_domain_name',
          'configuration_hash',
          'persistent_disk',
          'template_hashes',
          'rendered_templates_archive',
        ]
        @full_spec.select {|k,_| keys.include?(k) }
      end
    end
  end
end
