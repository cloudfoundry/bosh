Sequel.migration do
  up do
    alter_table :local_dns_records do
      drop_index(nil, name: 'name_ip_idx')
      drop_column(:name)
      drop_foreign_key :instance_id
      add_foreign_key :instance_id, :instances, :null => true
    end

    self[:local_dns_records].delete

    self[:instances].each do |instance|
      begin
        instance_spec_json = JSON.parse(instance[:spec_json])
      rescue
        next
      end

      networks_json = instance_spec_json['networks']
      if networks_json == nil
        next
      end
      networks_json.each do |network_name, network|
        begin
          self[:local_dns_records] << {
              instance_id: instance[:id],
              instance_group: instance[:job],
              az: instance[:availability_zone],
              network: network_name,
              deployment: self[:deployments].first(id: instance[:deployment_id])[:name],
              ip: network['ip'],
          }
        rescue
          next
        end
      end
    end
  end
end
