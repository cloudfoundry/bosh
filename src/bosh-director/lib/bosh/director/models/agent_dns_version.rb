module Bosh::Director::Models
  class AgentDnsVersion < Sequel::Model(Bosh::Director::Config.db)
    def to_s
      "<#{self.class.name}-#{agent_id}/#{dns_version}>"
    end
  end
end
