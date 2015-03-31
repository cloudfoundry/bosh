module Bosh
  module Director
    module Models
      class CloudConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end
      end
    end
  end
end
