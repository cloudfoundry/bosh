# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Deployment < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :stemcells
    many_to_many :releases
    many_to_many :release_versions
    one_to_many  :job_instances, :class => "Bosh::Director::Models::Instance"
    one_to_many  :vms
    one_to_many  :properties, :class => "Bosh::Director::Models::DeploymentProperty"
    one_to_many  :problems, :class => "Bosh::Director::Models::DeploymentProblem"
    many_to_one   :cloud_config

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end
  end

  Deployment.plugin :association_dependencies
  Deployment.add_association_dependencies :stemcells => :nullify, :problems => :destroy
end
