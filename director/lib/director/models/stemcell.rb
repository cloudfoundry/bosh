# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Stemcell < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :deployments
    one_to_many :compiled_packages

    def validate
      validates_presence [:name, :version, :cid]
      validates_unique [:name, :version]
      validates_format VALID_ID, [:name, :version]
    end

    def desc
      "#{name}/#{version}"
    end
  end
end
