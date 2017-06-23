require 'yaml'

Sequel.migration do
  up do
    alter_table(:orphan_disks) do
      add_column :cpi, String, default: ''
    end

    latest_cloud_config_query = self[:cloud_configs].where(id: self[:cloud_configs].max(:id))
    if latest_cloud_config_query.any?
      begin
        latest_cloud_config = YAML::load(latest_cloud_config_query.first[:properties])
      rescue YAML::SyntaxError
        latest_cloud_config = {}
      end

      if latest_cloud_config.has_key?('azs')
        latest_cloud_config['azs'].each do |az_hash|
          name = az_hash['name']
          cpi_name = az_hash['cpi']
          self[:orphan_disks].where(availability_zone: name).update(cpi: cpi_name) if cpi_name
        end
      end
    end

    alter_table(:vms) do
      add_column :cpi, String, default: ''
    end

    # @todo self[].where(availability_zone != '', cpi: '').update(cpi: latest_cpi_config['cpis'][0]['name'])

    self[:vms].all.each do |vm|
      instance = self[:instances].where(id: vm[:instance_id]).first
      next if instance[:availability_zone].nil?

      deployment = self[:deployments].where(id: instance[:deployment_id]).first
      next if deployment[:cloud_config_id].nil?

      begin
        cloud_config = YAML::load(self[:cloud_configs].where(id: deployment[:cloud_config_id]).first[:properties])
      rescue YAML::SyntaxError
        cloud_config = {}
      end

      if cloud_config.has_key?('azs')
        cloud_config['azs'].each do |az_hash|
          next unless az_hash.has_key?('cpi')
          next if az_hash['name'] != instance[:availability_zone]

          self[:vms].where(id: vm[:id]).update(cpi: az_hash['cpi'])
        end
      end
    end
  end
end
