require_relative '../../spec/support/deployments'

Sham.define do
  name             { |index| "name-#{index}" }
  username         { |index| "username-#{index}" }
  object_name      { |index| "deployment-#{index}" }
  password         { |index| "password-#{index}" }
  version          { |index| "version-#{index}" }
  fingerprint      { |index| "fingerprint-#{index}" }
  manifest         { |index| "manifest-#{index}" }
  job              { |index| "job-#{index}" }
  vm_cid           { |index| "vm-cid-#{index}" }
  disk_cid         { |index| "disk-cid-#{index}" }
  network_cid      { |index| "network-cid-#{index}" }
  snapshot_cid     { |index| "snapshot-cid-#{index}" }
  stemcell_cid     { |index| "stemcell-cid-#{index}" }
  stemcell_os      { |index| "stemcell-os-#{index}" }
  stemcell_version { |index| "stemcell-version-#{index}" }
  instance_id      { |index| "instance-id-#{index}" }
  blobstore_id     { |index| "blobstore-id-#{index}" }
  agent_id         { |index| "agent-id-#{index}" }
  uuid             { |index| "uuid-#{index}" }
  director_uuid    { |index| "director-uuid-#{index}" }
  index            { |index| index }
  description      { |index| "description #{index}" }
  type             { |index| "type #{index}" }
  sha1             { |index| "sha1-#{index}" }
  build            { |index| index }
  ip               do |index|
    octet = index % 255
    "#{octet}.#{octet}.#{octet}.#{octet}"
  end
  ptr do |index|
    octet = index % 255
    "#{octet}.#{octet}.#{octet}.in-addr.arpa"
  end
  lock_name { |index| "lock-resource-entity#{index}" }
  id { |index| index }
end

module Bosh::Director::Models
  DirectorAttribute.blueprint do
    name { 'uuid' }
    value { Sham.director_uuid }
  end

  Release.blueprint do
    name { Sham.name }
  end

  ReleaseVersion.blueprint do
    release { Release.make }
    version { Sham.version }
  end

  Package.blueprint do
    release             { Release.make }
    name                { Sham.name }
    version             { Sham.version }
    blobstore_id        { Sham.blobstore_id }
    sha1                { Sham.sha1 }
    dependency_set_json { '[]' }
  end

  Template.blueprint do
    release
    name                { Sham.name }
    version             { Sham.version }
    blobstore_id        { Sham.blobstore_id }
    sha1                { Sham.sha1 }
    package_names_json  { '[]' }
    fingerprint         { Sham.fingerprint }
  end

  Stemcell.blueprint do
    name      { Sham.name }
    id        { Sham.id }
    version   { Sham.version }
    cid       { Sham.stemcell_cid }
    operating_system { Sham.name }
  end

  StemcellUpload.blueprint do
    name      { Sham.name }
    version   { Sham.version }
  end

  CompiledPackage.blueprint do
    package           { Package.make }
    build             { Sham.build }
    blobstore_id      { Sham.blobstore_id }
    sha1              { Sham.sha1 }
    stemcell_os       { Sham.stemcell_os }
    stemcell_version  { Sham.stemcell_version }
    dependency_key    { '[]' }
  end

  Deployment.blueprint do
    name      { Sham.name }
    manifest  { Sham.manifest }
  end

  Instance.blueprint do
    deployment
    job         { Sham.job }
    index       { Sham.index }
    state       { 'started' }
    uuid        { Sham.uuid }
    variable_set
  end

  IpAddress.blueprint do
    address_str { NetAddr::CIDR.create(Sham.ip).to_i.to_s }
    vm { nil }
    instance
    static { false }
    network_name { Sham.name }
    task_id { Sham.name }
    created_at { Time.now }
  end

  Task.blueprint do
    state       { 'queued' }
    type        { Sham.type }
    timestamp   { Time.now }
    description { Sham.description }
    result      { nil }
    output      { nil }
    result_output { nil }
    event_output { nil }
  end

  PersistentDisk.blueprint do
    active      { true }
    disk_cid    { Sham.disk_cid }
    instance    { Vm.make(:active).instance }
  end

  Network.blueprint do
    name { Sham.name }
    type { 'manual' }
    created_at { Time.now }
    orphaned { false }
    orphaned_at { nil }
  end

  Subnet.blueprint do
    name { Sham.name }
    cid { Sham.network_cid }
    range { '192.168.10.0/24' }
    gateway { '192.168.10.1' }
    reserved { '[]' }
    cloud_properties { '{}' }
    cpi { '' }
    network { Network.make }
  end

  Snapshot.blueprint do
    persistent_disk { PersistentDisk.make }
    snapshot_cid    { Sham.snapshot_cid }
  end

  OrphanDisk.blueprint do
    deployment_name { Sham.name }
    disk_cid        { Sham.disk_cid }
    instance_name   { Sham.name }
  end

  OrphanedVm.blueprint do
    cid               { Sham.vm_cid }
    deployment_name   { Sham.name }
    instance_name     { Sham.name }
    availability_zone { Sham.name }
    orphaned_at       { Time.now }
  end

  OrphanSnapshot.blueprint do
    orphan_disk         { OrphanDisk.make }
    snapshot_cid        { Sham.snapshot_cid }
    snapshot_created_at { Time.now }
  end

  DeploymentProblem.blueprint do
    deployment  { Deployment.make }
    type        { 'inactive_disk' }
    resource_id { PersistentDisk.make.id }
    data_json   { '{}' }
    state       { 'open' }
  end

  RenderedTemplatesArchive.blueprint do
    instance     { Instance.make }
    blobstore_id { Sham.blobstore_id }
    sha1         { Sham.sha1 }
    content_sha1 { Sham.sha1 }
    created_at   { Time.now }
  end

  Config.blueprint do
    type { 'my-type' }
    name { 'some-name' }
    content { '--- {}' }
    created_at { Time.now }
  end

  Config.blueprint(:cloud) do
    type { 'cloud' }
    name { 'default' }
  end

  Config.blueprint(:cloud_with_manifest) do
    type { 'cloud' }
    name { 'default' }
    content { YAML.dump(Bosh::Spec::Deployments.simple_cloud_config) }
  end

  Config.blueprint(:cloud_with_manifest_v2) do
    type { 'cloud' }
    name { 'default' }
    content { YAML.dump(Bosh::Spec::Deployments.simple_cloud_config) }
  end

  Config.blueprint(:runtime) do
    type { 'runtime' }
    name { 'default' }
  end

  Config.blueprint(:cpi) do
    type { 'cpi' }
    name { 'default' }
  end

  Config.blueprint(:cpi_with_manifest) do
    type { 'cpi' }
    name { 'default' }
    content { YAML.dump(Bosh::Spec::Deployments.multi_cpi_config) }
  end

  DeploymentProperty.blueprint do
    deployment { Deployment.make }
    name       { Sham.name }
    value      { 'value' }
  end

  Lock.blueprint do
    name        { Sham.lock_name }
    expired_at  { Time.now }
    uid         { SecureRandom.uuid }
  end

  LogBundle.blueprint do
    timestamp     { Time.now }
    blobstore_id  { Sham.blobstore_id }
  end

  Event.blueprint do
    action      { 'create' }
    object_type { 'deployment' }
    object_name { Sham.object_name }
    user        { Sham.username }
    timestamp   { Time.now }
  end

  Team.blueprint do
    name { Sham.name }
  end

  ErrandRun.blueprint {}

  Blob.blueprint do
    blobstore_id { Sham.blobstore_id }
    sha1         { Sham.sha1 }
    created_at   { Time.new }
  end

  LocalDnsBlob.blueprint do
    created_at   { Time.new }
    blob         { Blob.make(type: 'dns') }
    version      { 1 }
  end

  LocalDnsEncodedNetwork.blueprint do
    id { 1 }
    name { 'fake-network-1' }
  end

  LocalDnsRecord.blueprint do
    ip          { Sham.ip }
    instance_id { Sham.instance_id }
  end

  VariableSet.blueprint do
    deployment { Deployment.make }
    writable { false }
  end

  Variable.blueprint {}

  Vm.blueprint do
    instance { Instance.make }
    cid      { Sham.vm_cid }
    agent_id { Sham.agent_id }
    created_at { Time.now }
  end

  Vm.blueprint(:active) do
    active { true }
  end

  module Links
    LinkProvider.blueprint do
      name           { Sham.name }
      type           { Sham.name }
      deployment     { Deployment.make }
      instance_group { Sham.name }
    end
    LinkProviderIntent.blueprint do
      name          { Sham.name }
      original_name { Sham.name }
      type          { Sham.name }
      link_provider { LinkProvider.make }
    end
    LinkConsumer.blueprint do
      name       { Sham.name }
      type       { Sham.name }
      deployment { Deployment.make }
    end
    LinkConsumerIntent.blueprint do
      name          { Sham.name }
      original_name { Sham.name }
      type          { Sham.name }
      link_consumer { LinkConsumer.make }
    end
    Link.blueprint do
      name                 { Sham.name }
      link_consumer_intent { LinkConsumerIntent.make }
      link_content         { '{}' }
    end
  end
end
