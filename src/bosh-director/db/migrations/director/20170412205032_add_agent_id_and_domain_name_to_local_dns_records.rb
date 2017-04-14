Sequel.migration do
  up do
    alter_table :local_dns_records do
      add_column :agent_id, String
      add_column :domain, String
    end

    self[:local_dns_records].each do |local_dns_record|
      next if local_dns_record[:instance_id].nil?

      vm = self[:vms].where(
        instance_id: local_dns_record[:instance_id],
        active: true,
      ).first

      next if vm.nil?

      self[:local_dns_records].where(id: local_dns_record[:id]).update(
        agent_id: vm[:agent_id],
      )
    end
  end
end
