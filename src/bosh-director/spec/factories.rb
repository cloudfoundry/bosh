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
