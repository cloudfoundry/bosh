module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    many_to_one :vm
    many_to_one :orphaned_vm

    def validate
      raise 'No instance or orphaned VM associated with IP' if instance_id.nil? && orphaned_vm_id.nil?
      raise 'IP address cannot have both instance id and orphaned VM id' if !instance_id.nil? && !orphaned_vm_id.nil?
      validates_presence :instance_id, allow_nil: true
      validates_presence :orphaned_vm_id, allow_nil: true
      validates_presence :task_id
      validates_presence :address_str
      validates_unique :address_str
      raise 'Invalid type for address_str column' unless address_str.is_a?(String)
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      [
        "#{instance.deployment.name}.#{instance.job}/#{instance.index}",
        network_name,
        "#{Bosh::Director::IpAddrOrCidr.new(address_str.to_i)} (#{type})"
      ].join(' - ')
    end

    def formatted_ip
      Bosh::Director::IpAddrOrCidr.new(address).to_s
    end

    def type
      static ? 'static' : 'dynamic'
    end

    def address
      unless address_str.match?(/\A\d+\z/)
        info_display = ''
        begin
          info_display = info
        rescue StandardError
          info_display = 'missing_info'
        end
        raise "Unexpected address '#{address_str}' (#{info_display})"
      end
      address_str.to_i
    end

    def to_s
      info
    end
  end
end
