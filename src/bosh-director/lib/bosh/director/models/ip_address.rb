module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    many_to_one :vm
    many_to_one :orphaned_vm

    def validate
      validates_presence :instance_id
      validates_presence :task_id
      validates_presence :address_str
      validates_unique :address_str
      raise 'Invalid type for address_str column' unless address_str.is_a?(String)
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      instance_info = "#{instance.deployment.name}.#{instance.job}/#{instance.index}"
      formatted_ip = NetAddr::CIDR.create(address_str.to_i).ip
      "#{instance_info} - #{network_name} - #{formatted_ip} (#{type})"
    end

    def formatted_ip
      NetAddr::CIDR.create(address).ip
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
