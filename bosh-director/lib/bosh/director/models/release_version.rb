# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class ReleaseVersion < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :release
    many_to_many :packages
    many_to_many :templates
    many_to_many :deployments

    def validate
      validates_presence [:release_id, :version]
      validates_unique [:release_id, :version]
      validates_format VALID_ID, :version
    end
  end
end
