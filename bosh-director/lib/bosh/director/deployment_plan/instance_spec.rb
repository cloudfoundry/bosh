module Bosh::Director
  module DeploymentPlan
    class InstanceSpec
      def initialize(deployment_name, instance_plan)
        @deployment_name = deployment_name
        @job = instance_plan.instance.job
        @instance = instance_plan.instance
        @instance_plan = instance_plan
        @dns_manager = DnsManager.create
      end

      def template_spec
        spec = {
          'deployment' => @deployment_name,
          'job' => @job.spec,
          'index' => @instance.index,
          'bootstrap' => @instance.bootstrap?,
          'id' => @instance.uuid,
          'availability_zone' => @instance.availability_zone_name,
          'networks' => @instance_plan.network_settings_hash,
          'vm_type' => @job.vm_type.spec,
          'stemcell' => @job.stemcell.spec,
          'env' => @job.env.spec,
          'packages' => @job.package_spec,
          'properties' => @job.properties,
          'dns_domain_name' => @dns_manager.dns_domain_name,
          'links' => @job.link_spec,
        }

        if @job.persistent_disk_type
          # supply both for reverse compatibility with old agent
          spec['persistent_disk'] = @job.persistent_disk_type.disk_size
          # old agents will ignore this pool
          # keep disk pool for backwards compatibility
          spec['persistent_disk_pool'] = @job.persistent_disk_type.spec
          spec['persistent_disk_type'] = @job.persistent_disk_type.spec
        else
          spec['persistent_disk'] = 0
        end

        if @instance.template_hashes
          spec['template_hashes'] = @instance.template_hashes
        end

        spec
      end

      def apply_spec
        spec = {
          'deployment' => @deployment_name,
          'job' => @job.spec,
          'index' => @instance.index,
          'id' => @instance.uuid,
          'networks' => @instance_plan.network_settings_hash,
          'vm_type' => @job.vm_type.spec,
          'stemcell' => @job.stemcell.spec,
          'packages' => @job.package_spec,
          'configuration_hash' => @instance.configuration_hash,
          'dns_domain_name' => @dns_manager.dns_domain_name,
        }

        if @job.env
          spec['env'] = @job.env.spec
        end

        if @job.persistent_disk_type
          spec['persistent_disk'] = @job.persistent_disk_type.disk_size
        else
          spec['persistent_disk'] = 0
        end

        if @instance.template_hashes
          spec['template_hashes'] = @instance.template_hashes
        end

        if @instance.rendered_templates_archive
          spec['rendered_templates_archive'] = @instance.rendered_templates_archive.spec
        end

        spec
      end
    end
  end
end
