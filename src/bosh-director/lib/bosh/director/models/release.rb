module Bosh::Director::Models
  class Release < Sequel::Model(Bosh::Director::Config.db)
    one_to_many :versions, :class => "Bosh::Director::Models::ReleaseVersion"
    one_to_many :packages
    one_to_many :templates

    many_to_many :deployments

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end
  end
end
