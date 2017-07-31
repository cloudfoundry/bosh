require_relative '../../spec/support/deployments'

Sham.define do
  name             { |index| "name-#{index}" }
  username         { |index| "username-#{index}" }
  object_name      { |index| "deployment-#{index}" }
  password         { |index| "password-#{index}" }
  version          { |index| "version-#{index}" }
  manifest         { |index| "manifest-#{index}" }
  job              { |index| "job-#{index}"}
  vm_cid           { |index| "vm-cid-#{index}" }
  disk_cid         { |index| "disk-cid-#{index}" }
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
  ip               { |index|
                     octet = index % 255
                     "#{octet}.#{octet}.#{octet}.#{octet}"
                   }
  ptr              { |index|
                     octet = index % 255
                     "#{octet}.#{octet}.#{octet}.in-addr.arpa"
                   }
  lock_name     { |index| "lock-resource-entity#{index}" }
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
    dependency_set_json { "[]" }
  end

  Template.blueprint do
    release
    name                { Sham.name }
    version             { Sham.version }
    blobstore_id        { Sham.blobstore_id }
    sha1                { Sham.sha1 }
    package_names_json  { "[]" }
  end

  Stemcell.blueprint do
    name      { Sham.name }
    version   { Sham.version }
    cid       { Sham.stemcell_cid }
  end

  CompiledPackage.blueprint do
    package           { Package.make }
    build             { Sham.build }
    blobstore_id      { Sham.blobstore_id }
    sha1              { Sham.sha1 }
    stemcell_os       { Sham.stemcell_os }
    stemcell_version  { Sham.stemcell_version }
    dependency_key    { "[]" }
  end

  Deployment.blueprint do
    name      { Sham.name }
    manifest  { Sham.manifest }
  end

  Instance.blueprint do
    deployment  { Deployment.make }
    job         { Sham.job }
    index       { Sham.index }
    state       { 'started' }
    uuid        { Sham.uuid }
    variable_set { VariableSet.make }
  end

  AvailabilityZone.blueprint do
    name { Sham.name }
  end

  IpAddress.blueprint do
    address { NetAddr::CIDR.create(Sham.ip) }
    instance  { Instance.make }
    static { false }
    network_name { Sham.name }
    task_id { Sham.name }
    created_at { Time.now }
  end

  Task.blueprint do
    state       { "queued" }
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
    instance    do
      is = Instance.make
      vm = Vm.make(instance_id: is.id)
      is.active_vm = vm
    end
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

  OrphanSnapshot.blueprint do
    orphan_disk         { OrphanDisk.make }
    snapshot_cid        { Sham.snapshot_cid }
    snapshot_created_at { Time.now }
  end

  DeploymentProblem.blueprint do
    deployment  { Deployment.make }
    type        { "inactive_disk" }
    resource_id { PersistentDisk.make.id }
    data_json   { "{}" }
    state       { "open" }
  end

  RenderedTemplatesArchive.blueprint do
    instance     { Instance.make }
    blobstore_id { Sham.blobstore_id }
    sha1         { Sham.sha1 }
    content_sha1 { Sham.sha1 }
    created_at   { Time.now }
  end

  CloudConfig.blueprint do
    raw_manifest { Bosh::Spec::Deployments.simple_cloud_config }
  end

  RuntimeConfig.blueprint do
    raw_manifest { Bosh::Spec::Deployments.simple_runtime_config }
  end

  CpiConfig.blueprint do
    manifest { Bosh::Spec::Deployments.simple_cpi_config }
  end

  DeploymentProperty.blueprint do
    deployment { Deployment.make }
    name       { Sham.name }
    value      { "value" }
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
    action      { 'create'}
    object_type {'deployment' }
    object_name { Sham.object_name }
    user        { Sham.username }
    timestamp   { Time.now }
  end

  Team.blueprint do
    name      { Sham.name }
  end

  ErrandRun.blueprint do
    instance_id { Instance.make.id }
    successful  { false }
  end

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

  LocalDnsRecord.blueprint do
    ip          { Sham.ip }
    instance_id { Sham.instance_id }
  end

  VariableSet.blueprint {
    deployment { Deployment.make }
  }

  Variable.blueprint {}

  Vm.blueprint do
    cid      { Sham.vm_cid }
    agent_id { Sham.agent_id }
  end

  module Dns
    Domain.blueprint do
      name     { Sham.name }
      type     { "NATIVE" }
    end

    Record.blueprint do
      domain   { Domain.make }
      name     { Sham.name }
      type     { "A" }
      content  { Sham.ip }
    end

    Record.blueprint(:PTR) do
      domain   { Domain.make }
      name     { Sham.ptr }
      type     { "PTR" }
      content  { Sham.name }
    end
  end
end
