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
        dns_manager = DnsManagerProvider.create

        spec = {
          'deployment' => deployment_name,
          'job' => instance_group.spec,
          'index' => instance.index,
          'bootstrap' => instance.bootstrap?,
          'name' => instance.job_name,
          'id' => instance.uuid,
          'az' => instance.availability_zone_name,
          'networks' => instance_plan.network_settings_hash,
          'vm_type' => instance_group.vm_type.spec,
          'stemcell' => instance_group.stemcell.spec,
          'env' => instance_group.env.spec,
          'uninterpolated_env' => instance_group.env.uninterpolated_spec,
          'packages' => instance_group.package_spec,
          'properties' => instance_group.properties,
          'properties_need_filtering' => true,
          'dns_domain_name' => dns_manager.dns_domain_name,
          'links' => instance_group.link_spec,
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
      end

      def as_template_spec
        TemplateSpec.new(full_spec).spec
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
      def initialize(full_spec)
        @full_spec = full_spec
        @dns_manager = DnsManagerProvider.create
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
          'address'
        ]
        template_hash = @full_spec.select {|k,v| keys.include?(k) }

        template_hash['properties'] = resolve_uninterpolated_values(@full_spec['properties'])
        template_hash['links'] = resolve_uninterpolated_values(@full_spec['links'])

        networks_hash = template_hash['networks']
        modified_networks_hash = networks_hash.each_pair do |network_name, network_settings|
          if @full_spec['job'] != nil
            settings_with_dns = network_settings.merge({'dns_record_name' => @dns_manager.dns_record_name(@full_spec['index'], @full_spec['job']['name'], network_name, @full_spec['deployment'])})
            networks_hash[network_name] = settings_with_dns
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
        'resource_pool' => @full_spec['vm_type']['name'],
        'networks' => modified_networks_hash
        })
      end

      private

      def resolve_uninterpolated_values(to_be_resolved_hash)
        return to_be_resolved_hash unless Bosh::Director::Config.config_server_enabled
        Bosh::Director::ConfigServer::ConfigParser.parse(to_be_resolved_hash)
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
