require 'securerandom'

module Bosh::Director::Models
  class Instance < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    one_to_many :persistent_disks
    one_to_many :rendered_templates_archives
    one_to_many :ip_addresses
    many_to_many :templates

    def validate
      validates_presence [:deployment_id, :job, :index, :state]
      validates_unique [:deployment_id, :job, :index]
      validates_integer :index
      validates_includes %w(started stopped detached), :state
    end

    def managed_persistent_disk
      PersistentDisk.first(active: true, name: '', instance: self)
    end

    def active_persistent_disks
      disk_collection = Bosh::Director::DeploymentPlan::PersistentDiskCollection.new(Bosh::Director::Config.logger)
      self.persistent_disks.select { |disk| disk.active }.each do |disk|
        disk_collection.add_by_model(disk)
      end
      disk_collection
    end

    # @todo[multi-disks] drop this method+calls since it's assuming a single persistent disk
    def managed_persistent_disk_cid
      disk = managed_persistent_disk
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
        return {} if spec.nil? || spec['vm_type'].nil?
        spec['vm_type']['cloud_properties'] || {}
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

    def name
      "#{self.job}/#{self.uuid}"
    end

    def to_s
      "#{self.job}/#{self.uuid} (#{self.index})"
    end

    def spec
      return nil if spec_json.nil?

      begin
        result = JSON.parse(spec_json)
      rescue JSON::ParserError
        return 'error'
      end

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
      if spec.nil?
        self.spec_json = nil
      else
        self.spec_json = JSON.generate(spec)
      end
    end

    def spec_p(property_path)
      current_prop = spec
      property_path.split('.').each do |prop|
        return nil if current_prop.nil? || !current_prop.is_a?(Hash)
        current_prop = current_prop[prop]
      end
      current_prop
    end

    def vm_env
      return {} if spec.nil?
      spec['env'] || {}
    end

    def credentials
      object_or_nil(credentials_json)
    end

    def credentials=(spec)
      self.credentials_json = json_encode(spec)
    end

    def lifecycle
      spec_hash = spec
      spec_hash ? spec_hash['lifecycle'] : nil
    end

    def expects_vm?
      lifecycle == 'service' && ['started', 'stopped'].include?(self.state)
    end

    private

    def object_or_nil(value)
      if value == 'null' || value.nil?
        nil
      else
        JSON.parse(value)
      end
    end

    def json_encode(value)
      value.nil? ? 'null' : JSON.generate(value)
    end
  end

  Instance.plugin :association_dependencies
  Instance.add_association_dependencies :ip_addresses => :destroy
  Instance.add_association_dependencies :templates => :nullify
end
