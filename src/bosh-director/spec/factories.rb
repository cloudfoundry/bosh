require 'factory_bot'

FactoryBot.define do
  factory :stemcell, class: Bosh::Director::DeploymentPlan::Stemcell do
    add_attribute(:alias) { 'default' }
    name { 'bosh-ubuntu-xenial-with-ruby-agent' }
    os { 'ubuntu-xenial' }
    version { '250.1' }

    initialize_with { new(self.alias, name, os, version) }
  end
end

FactoryBot.define do
  factory :manual_network, class: Bosh::Director::DeploymentPlan::ManualNetwork do
    name { 'manual-network-name' }
    subnets { [] }
    logger { Logging::Logger.new('TestLogger') }
    managed { false }

    initialize_with { new(name, subnets, logger, managed) }
  end
end

FactoryBot.define do
  factory :job_network, class: Bosh::Director::DeploymentPlan::JobNetwork do
    name { 'job-network-name' }
    static_ips { [] }
    default_for { [] }
    association :deployment_network, factory: :manual_network, strategy: :build

    initialize_with { new(name, static_ips, default_for, deployment_network) }
  end
end

module Bosh::Director
  module DeploymentPlan
    [Stemcell, ManualNetwork, JobNetwork].each do |klass|
      klass.class_eval do
        def self.make(*args)
          FactoryBot.build(name.demodulize.underscore.to_sym, *args)
        end
      end
    end
  end
end
