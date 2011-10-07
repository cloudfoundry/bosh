module Bosh::Director::Models
  class Release < Sequel::Model
    one_to_many :versions, :class => "Bosh::Director::Models::ReleaseVersion"
    one_to_many :packages
    one_to_many :templates
    one_to_many :deployments
    one_to_many  :properties, :class => "Bosh::Director::Models::ReleaseProperty"

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end
  end
end
