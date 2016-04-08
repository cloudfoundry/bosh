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
        job = instance_plan.desired_instance.job
        instance_plan = instance_plan
        dns_manager = DnsManagerProvider.create

        spec = {
          'deployment' => deployment_name,
          'job' => job.spec,
          'index' => instance.index,
          'bootstrap' => instance.bootstrap?,
          'name' => instance.job_name,
          'id' => instance.uuid,
          'az' => instance.availability_zone_name,
          'networks' => instance_plan.network_settings_hash,
          'vm_type' => job.vm_type.spec,
          'stemcell' => job.stemcell.spec,
          'env' => job.env.spec,
          'packages' => job.package_spec,
          'properties' => job.properties,
          'properties_need_filtering' => true,
          'dns_domain_name' => dns_manager.dns_domain_name,
          'links' => job.link_spec,
          'address' => instance_plan.network_settings.network_address,
          'update' => job.update_spec
        }

        if job.persistent_disk_type
          # supply both for reverse compatibility with old agent
          spec['persistent_disk'] = job.persistent_disk_type.disk_size
          # old agents will ignore this pool
          # keep disk pool for backwards compatibility
          spec['persistent_disk_pool'] = job.persistent_disk_type.spec
          spec['persistent_disk_type'] = job.persistent_disk_type.spec
        else
          spec['persistent_disk'] = 0
        end

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
          'properties',
          'properties_need_filtering',
          'dns_domain_name',
          'links',
          'persistent_disk',
          'address'
        ]
        template_hash = @full_spec.select {|k,v| keys.include?(k) }

        networks_hash = template_hash['networks']
        networks_hash_with_dns = networks_hash.each_pair do |network_name, network_settings|
          if @full_spec['job'] != nil
            settings_with_dns = network_settings.merge({'dns_record_name' => @dns_manager.dns_record_name(@full_spec['index'], @full_spec['job']['name'], network_name, @full_spec['deployment'])})
            networks_hash[network_name] = settings_with_dns
          end
        end

        template_hash.merge({
        'resource_pool' => @full_spec['vm_type']['name'],
        'networks' => networks_hash_with_dns
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
