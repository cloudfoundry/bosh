module Bosh::Director::Models
  class OrphanedVm < Sequel::Model(Bosh::Director::Config.db)
    one_to_many :ip_addresses

    def self.list_all
      dataset.all.map do |vm|
        {
          'az' => vm.availability_zone,
          'cid' => vm.cid,
          'deployment_name' => vm.deployment_name,
          'instance_name' => vm.instance_name,
          'ip_addresses' => vm.ip_addresses.map(&:formatted_ip),
          'orphaned_at' => vm.orphaned_at.to_s,
        }
      end
    end
  end
end
