require 'yaml'

Sequel.migration do
  up do
    alter_table(:persistent_disks) do
      add_column :cpi, String, default: ''
    end

    self[:persistent_disks].all.each do |disk|
      instance = self[:instances].where(id: disk[:instance_id]).first
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

          self[:persistent_disks].where(id: disk[:id]).update(cpi: az_hash['cpi'])
        end
      end
    end
  end
end
