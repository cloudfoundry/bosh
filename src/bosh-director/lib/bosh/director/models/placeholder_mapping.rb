module Bosh::Director::Models
  class PlaceholderMapping < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence :placeholder_name
      validates_presence :placeholder_id
    end
  end
end
