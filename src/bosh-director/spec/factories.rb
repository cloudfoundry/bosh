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

module Bosh::Director
  module DeploymentPlan
    [Stemcell].each do |klass|
      klass.class_eval do
        def self.make(*args)
          FactoryBot.build(name.demodulize.downcase.to_sym, *args)
        end
      end
    end
  end
end
