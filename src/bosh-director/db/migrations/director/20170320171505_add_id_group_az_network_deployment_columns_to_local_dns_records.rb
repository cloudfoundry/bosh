Sequel.migration do
  up do
    alter_table(:local_dns_records) do
      add_column :az, String
      add_column :instance_group, String
      add_column :network, String
      add_column :deployment, String
    end

    self[:local_dns_records].each do |local_dns_record|
      next if local_dns_record[:instance_id] == nil
      instance = self[:instances].first(id: local_dns_record[:instance_id])

      begin
        instance_spec_json = JSON.parse(instance[:spec_json])
        network = instance_spec_json['networks'].find do |_, network|
          network['ip']== local_dns_record[:ip]
        end

        network_name = network.first
      rescue
        network_name = ''
      end

      self[:local_dns_records].where(id: local_dns_record[:id]).update({
        instance_group: instance[:job],
        network: network_name,
        deployment: self[:deployments].first(id: instance[:deployment_id])[:name],
        az: instance[:availability_zone],
      })
    end
  end
end
