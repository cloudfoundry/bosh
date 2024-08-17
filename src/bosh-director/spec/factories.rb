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

FactoryBot.define do
  to_create { |model| model.save(raise_on_failure: true) }

  factory :models_blob, class: Bosh::Director::Models::Blob do
    sequence(:blobstore_id) { |i| "blob-blobstore-id-#{i}" }
    sequence(:sha1) { |i| "blob-sha1-#{i}" }
    created_at { Time.now }
  end

  factory :models_compiled_package, class: Bosh::Director::Models::CompiledPackage do
    sequence(:build) { |i| "compiled-package-build-#{i}" }
    sequence(:blobstore_id) { |i| "compiled-package-blobstore-id-#{i}" }
    sequence(:sha1) { |i| "compiled-package-sha1-#{i}" }
    sequence(:stemcell_os) { |i| "compiled-package-stemcell-os-#{i}" }
    sequence(:stemcell_version) { |i| "compiled-package-stemcell-version-#{i}" }
    dependency_key { '[]' }
    association :package, factory: :models_package, strategy: :create
  end

  factory :models_config, class: Bosh::Director::Models::Config do
    sequence(:name) { |i| "config-#{i}" }
    sequence(:type) { |i| "config-type-#{i}" }
    content { '--- {}' }
    created_at { Time.now }
    transient do
      raw_manifest { nil }
    end

    after(:build) do |config, evaluator|
      config.tap do |c|
        c.raw_manifest = evaluator.raw_manifest if evaluator.raw_manifest
      end
    end

    factory :models_config_cloud do
      name { 'default' }
      type { 'cloud' }

      trait :with_manifest do
        content { YAML.dump(Bosh::Spec::Deployments.simple_cloud_config) }
      end
    end

    factory :models_config_cpi do
      name { 'default' }
      type { 'cpi' }

      trait :with_manifest do
        content { YAML.dump(Bosh::Spec::Deployments.multi_cpi_config) }
      end
    end

    factory :models_config_runtime do
      name { 'default' }
      type { 'runtime' }
    end
  end

  factory :models_deployment, class: Bosh::Director::Models::Deployment do
    sequence(:name) { |i| "deployment-#{i}" }
    sequence(:manifest) { |i| "deployment-manifest-#{i}" }
  end

  factory :models_deployment_property, class: Bosh::Director::Models::DeploymentProperty do
    sequence(:name) { |i| "deployment-property-#{i}" }
    sequence(:value) { |i| "deployment-property-value-#{i}" }
    association :deployment, factory: :models_deployment, strategy: :create
  end

  factory :models_director_attribute, class: Bosh::Director::Models::DirectorAttribute do
    name { 'uuid' }
    sequence(:value) { |i| "director-uuid-#{i}" }
  end

  factory :models_errand_run, class: Bosh::Director::Models::ErrandRun

  factory :models_event, class: Bosh::Director::Models::Event do
    action { 'create' }
    object_type { 'deployment' }
    sequence(:object_name) { |i| "event-object-name-#{i}" }
    sequence(:user) { |i| "event-user-#{i}" }
    timestamp { Time.now }
  end

  factory :models_links_link, class: Bosh::Director::Models::Links::Link do
    sequence(:name) { |i| "link-#{i}" }
    link_content { '{}' }
    association :link_consumer_intent, factory: :models_links_link_consumer_intent, strategy: :create
  end

  factory :models_links_link_consumer, class: Bosh::Director::Models::Links::LinkConsumer do
    sequence(:name) { |i| "link-consumer-#{i}" }
    sequence(:type) { |i| "link-consumer-type-#{i}" }
    association :deployment, factory: :models_deployment, strategy: :create
  end

  factory :models_links_link_consumer_intent, class: Bosh::Director::Models::Links::LinkConsumerIntent do
    sequence(:name) { |i| "link-consumer-intent-#{i}" }
    sequence(:original_name) { |i| "link-consumer-intent-original-name-#{i}" }
    sequence(:type) { |i| "link-consumer-intent-type-#{i}" }
    association :link_consumer, factory: :models_links_link_consumer, strategy: :create
  end

  factory :models_links_link_provider, class: Bosh::Director::Models::Links::LinkProvider do
    sequence(:name) { |i| "link-provider-#{i}" }
    sequence(:type) { |i| "link-provider-type-#{i}" }
    sequence(:instance_group) { |i| "link-provider-instance-group-#{i}" }
    association :deployment, factory: :models_deployment, strategy: :create
  end

  factory :models_links_link_provider_intent, class: Bosh::Director::Models::Links::LinkProviderIntent do
    sequence(:name) { |i| "link-provider-intent-#{i}" }
    sequence(:original_name) { |i| "link-provider-intent-original-name-#{i}" }
    sequence(:type) { |i| "link-provider-intent-type-#{i}" }
    association :link_provider, factory: :models_links_link_provider, strategy: :create
  end

  factory :models_log_bundle, class: Bosh::Director::Models::LogBundle do
    sequence(:blobstore_id) { |i| "log-bundle-blobstore-id-#{i}" }
    timestamp { Time.now }
  end

  factory :models_local_dns_blob, class: Bosh::Director::Models::LocalDnsBlob do
    version { 1 }
    created_at { Time.now }
    association :blob, factory: :models_blob, strategy: :create
  end

  factory :models_local_dns_encoded_network, class: Bosh::Director::Models::LocalDnsEncodedNetwork do
    sequence(:name) { |i| "local-dns-encoded-network-#{i}" }
  end

  factory :models_local_dns_record, class: Bosh::Director::Models::LocalDnsRecord do
    sequence(:ip) { |i| "#{i % 255}.#{i % 255}.#{i % 255}.#{i % 255}" }
    sequence(:instance_id) { |i| "local-dns-record-instance-id-#{i}" }
  end

  factory :models_lock, class: Bosh::Director::Models::Lock do
    sequence(:name) { |i| "lock-#{i}" }
    sequence(:uid) { |i| "lock-uid-#{i}" }
    expired_at { Time.now }
  end

  factory :models_instance, class: Bosh::Director::Models::Instance do
    sequence(:job) { |i| "instance-job-#{i}" }
    sequence(:index) { |i| i }
    state { 'started' }
    sequence(:uuid) { |i| "instance-uuid-#{i}" }
    association :deployment, factory: :models_deployment, strategy: :create
    association :variable_set, factory: :models_variable_set, strategy: :create
  end

  factory :models_network, class: Bosh::Director::Models::Network do
    sequence(:name) { |i| "network-#{i}" }
    type { 'manual' }
    created_at { Time.now }
    orphaned { false }
    orphaned_at { nil }
  end

  factory :models_orphaned_vm, class: Bosh::Director::Models::OrphanedVm do
    sequence(:cid) { |i| "orphaned-vm-cid-#{i}" }
    sequence(:deployment_name) { |i| "orphaned-vm-deployment-name-#{i}" }
    sequence(:instance_name) { |i| "orphaned-vm-instance-name-#{i}" }
    sequence(:availability_zone) { |i| "orphaned-vm-availability-zone-#{i}" }
    orphaned_at { Time.now }
  end

  factory :models_orphan_disk, class: Bosh::Director::Models::OrphanDisk do
    sequence(:deployment_name) { |i| "orphan-disk-deployment-name-#{i}" }
    sequence(:disk_cid) { |i| "orphan-disk-disk-cid-#{i}" }
    sequence(:instance_name) { |i| "orphan-disk-instance-name-#{i}" }
  end

  factory :models_orphan_snapshot, class: Bosh::Director::Models::OrphanSnapshot do
    sequence(:snapshot_cid) { |i| "orphan-snapshot-cid-#{i}" }
    snapshot_created_at { Time.now }
    association :orphan_disk, factory: :models_orphan_disk, strategy: :create
  end

  factory :models_package, class: Bosh::Director::Models::Package do
    sequence(:name) { |i| "package-#{i}" }
    sequence(:version) { |i| "package-v#{i}" }
    sequence(:blobstore_id) { |i| "package-blobstore-id-#{i}" }
    sequence(:sha1) { |i| "package-sha1-#{i}" }
    dependency_set_json { '[]' }
    association :release, factory: :models_release, strategy: :create
  end

  factory :models_release, class: Bosh::Director::Models::Release do
    sequence(:name) { |i| "release-#{i}" }
  end

  factory :models_release_version, class: Bosh::Director::Models::ReleaseVersion do
    sequence(:version) { |i| "release-version-v#{i}" }
    association :release, factory: :models_release, strategy: :create
  end

  factory :models_stemcell, class: Bosh::Director::Models::Stemcell do
    sequence(:name) { |i| "stemcell-#{i}" }
    sequence(:version) { |i| "stemcell-v#{i}" }
    sequence(:cid) { |i| "stemcell-cid-#{i}" }
    sequence(:operating_system) { |i| "stemcell-operating-system-#{i}" }
  end

  factory :models_stemcell_upload, class: Bosh::Director::Models::StemcellUpload do
    sequence(:name) { |i| "stemcell-upload-#{i}" }
    sequence(:version) { |i| "stemcell-upload-v#{i}" }
  end

  factory :models_subnet, class: Bosh::Director::Models::Subnet do
    sequence(:name) { |i| "subnet-#{i}" }
    sequence(:cid) { |i| "subnet-cid-#{i}" }
    range { '192.168.10.0/24' }
    gateway { '192.168.10.1' }
    reserved { '[]' }
    cloud_properties { '{}' }
    cpi { '' }
    association :network, factory: :models_network, strategy: :create
  end

  factory :models_task, class: Bosh::Director::Models::Task do
    state { 'queued' }
    timestamp { Time.now }
    sequence(:type) { |i| "task-type-#{i}" }
    sequence(:description) { |i| "task-description-#{i}" }
    traits_for_enum(:state, ['queued', 'processing', 'done', 'cancelling'])
  end

  factory :models_team, class: Bosh::Director::Models::Team do
    sequence(:name) { |i| "team-#{i}" }
  end

  factory :models_variable, class: Bosh::Director::Models::Variable

  factory :models_variable_set, class: Bosh::Director::Models::VariableSet do
    writable { false }
    association :deployment, factory: :models_deployment, strategy: :create
  end

  factory :models_template, class: Bosh::Director::Models::Template do
    sequence(:name) { |i| "template-#{i}" }
    sequence(:version) { |i| "template-v#{i}" }
    sequence(:blobstore_id) { |i| "template-blobstore-id-#{i}" }
    sequence(:sha1) { |i| "template-sha1-#{i}" }
    sequence(:fingerprint) { |i| "template-fingerprint-#{i}" }
    package_names_json { '[]' }
    association :release, factory: :models_release, strategy: :create
  end
end
