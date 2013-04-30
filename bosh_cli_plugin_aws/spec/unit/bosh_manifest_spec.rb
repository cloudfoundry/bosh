require 'spec_helper'

describe Bosh::Aws::BoshManifest do
  let(:vpc_receipt) { Psych.load_file(asset "test-output.yml") }
  let(:route53_receipt) { Psych.load_file(asset "test-aws_route53_receipt.yml") }
  let(:manifest_options) {{hm_director_user: 'hm', hm_director_password: 'hm_password'}}

  it "sets the correct elastic ip" do
    described_class.new(vpc_receipt, route53_receipt, 'deadbeef', manifest_options).vip.should == "50.200.100.3"
  end

  it "warns when vip is missing" do
    route53_receipt['elastic_ips']['bosh']['ips'] = []

    manifest = described_class.new(vpc_receipt, route53_receipt, 'deadbeef', manifest_options)
    manifest.should_receive(:warning).with("Missing vip field")
    manifest.to_y
  end

  it "generates the template" do
    manifest = YAML.load(described_class.new(vpc_receipt, route53_receipt, 'deadbeef', manifest_options).to_y)

    director_ssl_properties = manifest['properties']['director'].delete('ssl')
    director_ssl_properties['key'].should_not be_nil
    director_ssl_properties['cert'].should_not be_nil
    spec = YAML.dump(manifest).strip
    spec.should == (<<-YAML).strip
---
name: vpc-bosh-dev102
director_uuid: deadbeef
release:
  name: bosh
  version: latest
networks:
- name: default
  type: manual
  subnets:
  - range: 10.10.0.0/24
    gateway: 10.10.0.1
    static:
    - 10.10.0.7 - 10.10.0.9
    reserved:
    - 10.10.0.2 - 10.10.0.6
    - 10.10.0.10 - 10.10.0.10
    dns:
    - 10.10.0.6
    cloud_properties:
      subnet: subnet-4bdf6c26
- name: vip_network
  type: vip
  subnets:
  - range: 127.0.99.0/24
    gateway: 127.0.99.1
    dns:
    - 127.0.99.250
  cloud_properties:
    security_groups:
    - bosh
resource_pools:
- name: default
  stemcell:
    name: bosh-stemcell
    version: latest
  network: default
  size: 1
  cloud_properties:
    instance_type: m1.small
    availability_zone: us-east-1a
compilation:
  reuse_compilation_vms: true
  workers: 8
  network: default
  cloud_properties:
    instance_type: c1.medium
    availability_zone: us-east-1a
update:
  canaries: 1
  canary_watch_time: 30000 - 90000
  update_watch_time: 30000 - 90000
  max_in_flight: 1
  max_errors: 1
jobs:
- name: bosh
  template:
  - nats
  - blobstore
  - postgres
  - redis
  - powerdns
  - director
  - registry
  - health_monitor
  instances: 1
  resource_pool: default
  persistent_disk: 20480
  networks:
  - name: default
    default:
    - dns
    - gateway
    static_ips:
    - 10.10.0.7
  - name: vip_network
    static_ips:
    - 50.200.100.3
properties:
  template_only:
    aws:
      availability_zone: us-east-1a
  ntp:
  - 0.north-america.pool.ntp.org
  - 1.north-america.pool.ntp.org
  - 2.north-america.pool.ntp.org
  - 3.north-america.pool.ntp.org
  blobstore:
    address: 10.10.0.7
    port: 25251
    backend_port: 25552
    agent:
      user: agent
      password: ldsjlkadsfjlj
    director:
      user: director
      password: DirectoR
  networks:
    apps: default
    management: default
  nats:
    user: nats
    password: 0b450ada9f830085e2cdeff6
    address: 10.10.0.7
    port: 4222
  postgres:
    user: bosh
    password: a7a33139c8e3f34bc201351b
    address: 10.10.0.7
    port: 5432
    database: bosh
  redis:
    address: 10.10.0.7
    port: 25255
    password: R3d!S
  director:
    name: vpc-bosh-dev102
    address: 10.10.0.7
    port: 25555
    encryption: false
  hm:
    http:
      port: 25923
      user: admin
      password: admin
    director_account:
      user: hm
      password: hm_password
    intervals:
      poll_director: 60
      poll_grace_period: 30
      log_stats: 300
      analyze_agents: 60
      agent_timeout: 180
      rogue_agent_alert: 180
    loglevel: info
    email_notifications: false
    tsdb_enabled: false
    cloud_watch_enabled: true
    resurrector_enabled: true
  registry:
    address: 10.10.0.7
    http:
      port: 25777
      user: awsreg
      password: awsreg
  aws:
    access_key_id: ! '...'
    secret_access_key: ! '...'
    region: us-east-1
    default_key_name: dev102
    ec2_endpoint: ec2.us-east-1.amazonaws.com
    default_security_groups:
    - bosh
  dns:
    user: powerdns
    password: powerdns
    address: 10.10.0.7
    replication:
      user: foo
      password: bar
      basic_auth: foo:nosuchuser
    database:
      name: powerdns
      port: 5342
YAML
  end
end
