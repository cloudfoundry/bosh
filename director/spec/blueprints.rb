# Copyright (c) 2009-2012 VMware, Inc.

Sham.define do
  name          { |index| "name-#{index}" }
  username      { |index| "username-#{index}" }
  password      { |index| "password-#{index}" }
  version       { |index| "version-#{index}" }
  manifest      { |index| "manifest-#{index}" }
  job           { |index| "job-#{index}"}
  vm_cid        { |index| "vm-cid-#{index}" }
  disk_cid      { |index| "disk-cid-#{index}" }
  stemcell_cid  { |index| "stemcell-cid-#{index}" }
  blobstore_id  { |index| "blobstore-id-#{index}" }
  agent_id      { |index| "agent-id-#{index}" }
  index         { |index| index }
  description   { |index| "description #{index}"}
  sha1          { |index| "sha1-#{index}" }
  ip            { |index| "#{index % 255}.#{index % 255}.#{index % 255}.#{index % 255}"}
  build         { rand(1000) }
end

module Bosh::Director::Models

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
    stemcell          { Stemcell.make }
    build             { Sham.build }
    blobstore_id      { Sham.blobstore_id }
    sha1              { Sham.sha1 }
    dependency_key    { "[]" }
  end

  Deployment.blueprint do
    name      { Sham.name }
    manifest  { Sham.manifest }
  end

  Vm.blueprint do
    deployment  { Deployment.make }
    agent_id    { Sham.agent_id }
    cid         { Sham.vm_cid }
  end

  Instance.blueprint do
    deployment  { Deployment.make }
    job         { Sham.job }
    index       { Sham.index }
    vm          { Vm.make }
    state       { "started" }
  end

  Task.blueprint do
    state       { "queued" }
    timestamp   { Time.now }
    description { Sham.description }
    result      { nil }
    output      { nil }
  end

  User.blueprint do
    username { Sham.username }
    password { Sham.password }
  end

  PersistentDisk.blueprint do
    active      { true }
    disk_cid    { Sham.disk_cid }
    instance    { Instance.make }
  end

  DeploymentProblem.blueprint do
    deployment  { Deployment.make }
    type        { "inactive_disk" }
    resource_id { PersistentDisk.make.id }
    data_json   { "{}" }
    state       { "open" }
  end
end

module Bosh::Director::Models::Dns

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

end