require 'factory_bot'

FactoryBot.define do
  factory :deployment_plan_stemcell, class: Bosh::Director::DeploymentPlan::Stemcell do
    add_attribute(:alias) { 'default' }
    name { 'bosh-ubuntu-xenial-with-ruby-agent' }
    os { 'ubuntu-xenial' }
    version { '250.1' }

    initialize_with { new(self.alias, name, os, version) }
  end

  factory :deployment_plan_manual_network, class: Bosh::Director::DeploymentPlan::ManualNetwork do
    name { 'manual-network-name' }
    subnets { [] }
    logger { Logging::Logger.new('TestLogger') }
    managed { false }

    initialize_with { new(name, subnets, logger, managed) }
  end

  factory :deployment_plan_job_network, class: Bosh::Director::DeploymentPlan::JobNetwork do
    name { 'job-network-name' }
    static_ips { [] }
    default_for { [] }
    association :deployment_network, factory: :deployment_plan_manual_network, strategy: :build

    initialize_with { new(name, static_ips, default_for, deployment_network) }
  end

  factory :deployment_plan_instance_group, class: Bosh::Director::DeploymentPlan::InstanceGroup do
    name { 'instance-group-name' }
    logger { Logging::Logger.new('TestLogger') }
    canonical_name { 'instance-group-canonical-name' }
    lifecycle { 'service' }
    jobs { [] }
    persistent_disk_collection { Bosh::Director::DeploymentPlan::PersistentDiskCollection.new(logger) }
    env { Bosh::Director::DeploymentPlan::Env.new({}) }
    vm_type { nil }
    vm_resources { nil }
    vm_extensions { nil }
    update { Bosh::Director::DeploymentPlan::UpdateConfig.new(Bosh::Spec::Deployments.minimal_manifest['update']) }
    networks { [] }
    default_network { {} }
    availability_zones { [] }
    migrated_from { [] }
    state { nil }
    instance_states { {} }
    deployment_name { 'simple' }
    association :stemcell, factory: :deployment_plan_stemcell, strategy: :build

    initialize_with do
      new(
        name: name,
        canonical_name: canonical_name,
        lifecycle: lifecycle,
        jobs: jobs,
        stemcell: stemcell,
        logger: logger,
        persistent_disk_collection: persistent_disk_collection,
        env: env,
        vm_type: vm_type,
        vm_resources: vm_resources,
        vm_extensions: vm_extensions,
        update: update,
        networks: networks,
        default_network: default_network,
        availability_zones: availability_zones,
        migrated_from: migrated_from,
        state: state,
        instance_states: instance_states,
        deployment_name: deployment_name,
      )
    end
  end
end
