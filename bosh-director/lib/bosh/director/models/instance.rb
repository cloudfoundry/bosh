require 'securerandom'

module Bosh::Director::Models
  class Instance < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    many_to_one :vm
    one_to_many :persistent_disks
    one_to_many :rendered_templates_archives
    one_to_many :ip_addresses
    many_to_many :templates

    def validate
      validates_presence [:deployment_id, :job, :index, :state]
      validates_unique [:deployment_id, :job, :index]
      validates_unique [:vm_id] if vm_id
      validates_integer :index
      validates_includes %w(started stopped detached), :state
    end

    def persistent_disk
      # Currently we support only 1 persistent disk.
      self.persistent_disks.find { |disk| disk.active }
    end

    def persistent_disk_cid
      disk = persistent_disk
      return disk.disk_cid if disk
      nil
    end

    def latest_rendered_templates_archive
      rendered_templates_archives_dataset.order(:created_at).last
    end

    def stale_rendered_templates_archives
      stale_archives = rendered_templates_archives_dataset
      if latest = latest_rendered_templates_archive
        stale_archives.exclude(id: latest.id)
      else
        stale_archives
      end
    end

    def cloud_properties_hash
      if cloud_properties.nil?
        spec['vm_type']['cloud_properties']
      else
        JSON.parse(cloud_properties)
      end
    end

    def cloud_properties_hash=(hash)
      self.cloud_properties = JSON.dump(hash)
    end

    def dns_record_names
      return nil if dns_records.nil?

      JSON.parse(dns_records)
    end

    def dns_record_names=(list)
      self.dns_records = JSON.dump(list)
    end

    def to_s
      "#{self.job}/#{self.uuid} (#{self.index})"
    end

    def spec
      return nil if spec_json.nil?

      result = Yajl::Parser.parse(spec_json)
      if result['resource_pool'].nil?
        result
      else
        if result['vm_type'].nil?
          result['vm_type'] = {
            'name' => result['resource_pool']['name'],
            'cloud_properties' => result['resource_pool']['cloud_properties']
          }
        end

        if result['resource_pool']['stemcell'] && result['stemcell'].nil?
          result['stemcell'] = result['resource_pool']['stemcell']
          result['stemcell']['alias'] = result['resource_pool']['name']
        end

        result.delete('resource_pool')

        result
      end
    end

    def spec=(spec)
      self.spec_json = Yajl::Encoder.encode(spec)
    end

    def bind_to_vm_model(vm)
      self.vm = vm
    end

    def env
      if vm
        @env = vm.env
      else
        @env = {}
      end
      @env
    end
  end

  Instance.plugin :association_dependencies
  Instance.add_association_dependencies :ip_addresses => :destroy
  Instance.add_association_dependencies :templates => :nullify
end
