# BOSH CloudStack CPI

[![Build Status](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi.png?branch=master)](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi) [![Code Climate](https://codeclimate.com/github/cloudfoundry-community/bosh-cloudstack-cpi.png)](https://codeclimate.com/github/cloudfoundry-community/bosh-cloudstack-cpi)

A CPI for CloudStack from NTT & ZJU-SEL


## Current Status

* Working on merging source code from ZJU-SEL and NTT.
* Testing implementations both in basic zone and advanced zone.
* Successfully deploy Cloudfoundry v2 and run simple ruby app with Ubuntu12.04 template.


## Known Limitations

* Tested with CloudStack 4.0.0 & 4.2.0 with KVM

See also [the issue page](https://github.com/cloudfoundry-community/bosh-cloudstack-cpi/issues) for other known issues.


## How to Deploy Cloud Foundry on CloudStack


### Steps

* Create Inception Server
* Bootstrap Micro BOSH
* Deploy Cloud Foundry
* Setup Full BOSH (Optional)


### Create Inception server

You need a VM on the CloudStack domain where you install a BOSH instance using this CPI. This VM is so-called "inception" server. Install BOSH CLI and BOSH Deployer gems on the server and run all operations with them.


#### Create Security Groups or Firewall Rules

The inception server must have a security group which opens the TCP port 25889, which is used by the temporary BOSH Registry launched by BOSH Deployer. In advanced zone, you need to configure the firewall rule of inception server which opens the TCP port 25889 for the same reason.

You also need to create one or more security groups or firewall rules for VMs created by your BOSH instance. We recommend that you create a security group or firewall rule which opnens all the TCP and UDP ports for testing.


#### Boot a Ubuntu server

We recommend Ubuntu 12.04 64bit or later for your inception server. For those who use Ubuntu 12.10 or later we strongly recommand to select OS type with Ubuntu 10.04 or later while creating instance via ISO file or registering VM templates. Please don't select other Linux distributions like Centos or Apple Mac OS in case of some issues.(Issue #7)

CentOS is not tested and it would be not compatible with this CPI. Don't forget adding the security group which opens the port 25889 to the VM.


#### Install tools

You need some tools to generate stemcells and run the BOSH CLI commands.

```
# Basic tool
sudo apt-get install -y git
# Ruby and bundled gems
sudo apt-get install -y g++ make libxslt-dev libxml2-dev libsqlite3-dev zlib1g-dev libreadline-dev libssl-dev libcurl4-openssl-dev -y
# stemcell
sudo apt-get install -y libsqlite3-dev genisoimage libmysqlclient-dev libpq-dev debootstrap kpartx
```

You need also Ruby. Install Ruby 1.9.3 by your preferred method such as Rbenv, RVM and simply `apt-get install`.


#### Set up sudo

The user you runs commands as must be able to run the `sudo` command without the password. Use the `visudo` command and add the following line to your `/etc/sudoers` file.

```
your_user_name ALL=(ALL) NOPASSWD:ALL
```


#### Clone BOSH repository

To install BOSH gems and generate a stemcell with the CloudStack CPI, clone this repository to your preferred place.

```
git clone https://github.com/cloudfoundry-community/bosh-cloudstack-cpi.git ~/bosh
cd ~/bosh
git checkout ubuntu1204
```


#### Install dependent gems

Use Bundler to instal dependencies.

```
# Install the bundler gems if not installed
gem install bundler
# Install gems
bundle install
```


#### Generate Key Pair

BOSH requires at least one key pair to connect to created VM via SSH. You must generate your own key using the CloudStack API or on your dashboard site if provided.


##### Why do I need an inception server?

The CloudStack CPI creates stemcells, which are VM templates, by copying pre-composed disk images to data volumes which automatically attached by BOSH Deployer. This procedure is same as that of the AWS CPI and requires that the VM where BOSH Deployer works is running on the same domain where you want to deploy your BOSH instance.



### Bootstrap MicroBOSH

In this section, you will deploy a MicroBOSH instance as the bootstrap. Micro BOSH is an all-in-one setup for BOSH.


#### Generate Stemcell

MicroBOSH is provided as a VM image file so-called stemcell. You can create your stemcell by running the command below (takes about a half hour);


```sh
CANDIDATE_BUILD_NUMBER=3 bundle exec rake release:create_dev_release
sudo env PATH=$PATH CANDIDATE_BUILD_NUMBER=3 bundle exec rake "local:build_stemcell[cloudstack,ubuntu]"
# some tests for the generated stemcell currently fail
```

`CANDIDATE_BUILD_NUMBER` is any number (>= 3) which you like. You need increment this number when you create a new version of stemcell.

You will find the generated stemcell at `/mnt/stemcells/cloudstack/kvm/ubuntu/work/work/bosh-stemcell-3-cloudstack-kvm-ubuntu.tgz`.


#### Describe Deployment Manifest File

You need some settings about your MicroBOSH deployment. Create new directories (usually `deployments` and `deployments/firstbosh`) and write your manifest file using the template below. The manifest file must be saved with the file name `micro_bosh.yml` and in the child directoriy you created.

```sh
mkdir -p ~/deplyoments/firstbosh
cd ~/deployments/firstbosh
vi firstbosh/micro_bosh.yml
```

```yaml
---
name: firstbosh
logging:
  level: DEBUG
network:
  type: dynamic
resources:
  persistent_disk: 40960
  cloud_properties:
    instance_type: m1.medium
cloud:
  plugin: cloudstack
  properties:
    cloudstack:
      endpoint: <your_end_point_url> # Ask for your administrator
      api_key: <your_api_key> # You can find at your user page
      secret_access_key: <your_secret_access_key> # Same as above
      default_security_groups:
        - <security_groups_for_bosh> # Security group name which opens all TCP and UDP port
      default_key_name: <default_keypair_name> # Your keypair name (see the next section)
      private_key: <path_to_your_private_key> # The path to the private key file of your key pair
      state_timeout: 600
      stemcell_public_visibility: true
      default_zone: <default_zone_name> # Zone name of your instaption server
    registry:
      endpoint: http://admin:admin@<ip_address_of_your_inception_sever>:25889 # Use `ifconfig` to confirm
      user: admin
      password: admin
```


#### Generate SSH Key Pair

If you have no SSH key Pair registered to your CloudStack, you need generate one to enable SSH access to VM created by BOSH from the Director and CLI.

If your web console does not provide an interface to generate key pairs. Use the script below:

```ruby
#!/usr/bin/env ruby
require 'yaml'
require 'uri'
require 'fog'

settings = YAML.load(File.read(ARGV[0]))
name = ARGV[1]

endpoint_uri = URI.parse(settings['cloud']['properties']['cloudstack']['endpoint'])

fog_params = {
  :provider => 'CloudStack',
  :cloudstack_api_key => settings['cloud']['properties']['cloudstack']['api_key'],
  :cloudstack_secret_access_key => settings['cloud']['properties']['cloudstack']['secret_access_key'],
  :cloudstack_scheme => endpoint_uri.scheme,
  :cloudstack_host => endpoint_uri.host,
  :cloudstack_port => endpoint_uri.port,
  :cloudstack_path => endpoint_uri.path,
}

client = Fog::Compute.new(fog_params)

response = client.create_ssh_key_pair(name)
puts response['createsshkeypairresponse']['keypair']['privatekey']
```

You can run this script like:

```
# <script_name> <path_to_micro_bosh_yml> <key_pair_name>
./gen_key_pair ~/deployments/firstbosh/micro_bosh.yml bosh_test
```

And as script shows the private key, save it to the file path specifyed at `private_key` in `micro_bosh.yml`.


#### Deploy Micro BOSH

Deply your Micro BOSH instance with the BOSH CLI. By giving the path to the Gemfile in your cloned BOSH repository, you can use the BOSH CLI gems without install them with the `gem install` command.

```sh
cd ~/deployments
# Specify your manifest file
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh micro deployment firstbosh
# Then deploy
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh micro deploy
```

The command will show outputs like below:

```sh
Deploying new micro BOSH instance `firstbosh/micro_bosh.yml' to `Unknown Director' (type 'yes' to continue): yes

Verifying stemcell...
File exists and readable                                     OK
Verifying tarball...
Read tarball                                                 OK
Manifest exists                                              OK
Stemcell image file                                          OK
Stemcell properties                                          OK

Stemcell info
-------------
Name:    bosh-cloudstack-kvm-ubuntu
Version: 3


Deploy Micro BOSH
  unpacking stemcell (00:00:07)
  uploading stemcell (00:07:57)
  creating VM from ba607b72-95a9-4585-86f9-3d2b6b838c8a (00:01:48)
  waiting for the agent (00:01:14)
  create disk (00:00:00)
  mount disk (00:00:06)
  stopping agent services (00:00:01)
  applying micro BOSH spec (00:00:34)
  starting agent services (00:00:00)
  waiting for the director (00:00:24)
Done                    11/11 00:12:21
WARNING! Your target has been changed to `https://198.51.100.39:25555'!
Deployment set to '/home/cloudn/deployments/firstbosh/micro_bosh.yml'
Deployed `firstbosh/micro_bosh.yml' to `Unknown Director', took 00:12:21 to complete
```


#### Traget Your MicroBOSH

Now you can use your MicroBOSH. Target your instance with the `bosh target` command. As you will be asked a user name and its password, give `admin` to the both prompt.


```sh
# Use the IP address showed in the output of the `bosh deploy` command
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh target https://198.51.100.39:25555
Target set to `firstbosh'
Your username: admin
Enter password: *****
Logged in as `admin'
```

Then, show the status of your instance.

```sh
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh status
Config
             /home/cloudstack/.bosh_config

Director
  Name       firstbosh
  URL        https://198.51.100.39:25555
  Version    1.5.0.pre.3 (release:c2d634e3 bosh:c2d634e3)
  User       admin
  UUID       884aab78-3b73-495c-aa6f-b7fe9b2d7e1b
  CPI        cloudstack
  dns        enabled (domain_name: microbosh)
  compiled_package_cache disabled
  snapshots  disabled

Deployment
  not set
```



### Deploy Cloud Foundry on MicroBOSH

#### Upload a Release

Upload the source code and related resources of Cloud Foundry to your MicroBOSH. The cf-release repository has everything you need.

```sh
# Clone the repository
git clone https://github.com/cloudfoundry/cf-release.git ~/cf-release
cd cf-release
# Upload the latest release (147 at the moment)
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh upload release releases/cf-147.yml
```

This step takes some time.



#### Upload a Stemcell

Upload a stemcell to your MicroBOSH. You can use the same stemcell file which you used for bootstraping your MicroBOSH.

```sh
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh upload stemcell /mnt/stemcells/cloudstack/kvm/ubuntu/work/work/bosh-stemcell-3-cloudstack-kvm-ubuntu.tgz
```


#### Describe Manifest

Create your deployment manifest with the template below and save it whith your prefered name e.g. `cf.yml`.

```yaml
---
name: cf
director_uuid: 884aab78-3b73-494c-aa6f-b7fe9b2d7e1b # UUID shown by the bosh status command

releases:
 - name: cf
   version: 147 # Verison number of the uploded release

networks:
- name: default
  type: dynamic
  cloud_properties:
    security_groups:
    - bosh # Securiy group which opens all TCP and UDP ports

compilation:
  workers: 6
  network: default
  reuse_compilation_vms: true
  cloud_properties:
    instance_type: m1.medium
    ephemeral_volume: Datadisk 40GB # Data disk offering name of additonal disk

update:
  canaries: 1
  canary_watch_time: 30000-60000
  update_watch_time: 30000-60000
  max_in_flight: 4

resource_pools:
  - name: small
    network: default
    size: 8
    stemcell:
      name: bosh-cloudstack-kvm-ubuntu
      version: latest
    cloud_properties:
      instance_type: m1.small
      ephemeral_volume: Datadisk 40GB # Data disk offering name of additonal disk

  - name: large
    network: default
    size: 1
    stemcell:
      name: bosh-cloudstack-kvm-ubuntu
      version: latest
    cloud_properties:
      instance_type: m1.large
      ephemeral_volume: Datadisk 40GB # Data disk offering name of additional disk

jobs:
  - name: nats
    release: cf
    template:
      - nats
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: syslog_aggregator
    release: cf
    template:
      - syslog_aggregator
    instances: 1
    resource_pool: small
    persistent_disk: 65536
    networks:
      - name: default
        default: [dns, gateway]

  - name: postgres
    release: cf
    template:
      - postgres
    instances: 1
    resource_pool: small
    persistent_disk: 65536
    networks:
      - name: default
        default: [dns, gateway]
    properties:
      db: databases

  - name: nfs_server
    release: cf
    template:
      - debian_nfs_server
    instances: 1
    resource_pool: small
    persistent_disk: 65536
    networks:
      - name: default
        default: [dns, gateway]

  - name: uaa
    release: cf
    template:
      - uaa
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: cloud_controller
    release: cf
    template:
      - cloud_controller_ng
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]
    properties:
      ccdb: ccdb

  - name: router
    release: cf
    template:
      - gorouter
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: health_manager
    release: cf
    template:
      - health_manager_next
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: dea
    release: cf
    template: dea_next
    instances: 1
    resource_pool: large
    networks:
      - name: default
        default: [dns, gateway]

properties:

  domain: your.domain.name # replace these values with your domain name
  system_domain: your.domain.name
  system_domain_organization: your.domain.name
  app_domains:
    - your.domain.name

  networks:
    apps: default
    management: default

  nats:
    address: 0.nats.default.cf.microbosh
    port: 4222
    user: nats
    password: c1oudc0w
    authorization_timeout: 5

  router:
    port: 8081
    status:
      port: 8080
      user: gorouter
      password: c1oudcow

  dea: &dea
    memory_mb: 2048
    disk_mb: 20000
    directory_server_protocol: http

  dea_next: *dea

  syslog_aggregator:
    address: 0.syslog-aggregator.default.cf.microbosh
    port: 54321

  nfs_server:
    address: 0.nfs-server.default.cf.microbosh
    network: "*.cf.microbosh"
    idmapd_domain: your.domain.name

  debian_nfs_server:
    no_root_squash: true

  databases: &databases
    db_scheme: postgres
    address: 0.postgres.default.cf.microbosh
    port: 5524
    roles:
      - tag: admin
        name: ccadmin
        password: c1oudc0w
      - tag: admin
        name: uaaadmin
        password: c1oudc0w
    databases:
      - tag: cc
        name: ccdb
        citext: true
      - tag: uaa
        name: uaadb
        citext: true

  ccdb: &ccdb
    db_scheme: postgres
    address: 0.postgres.default.cf.microbosh
    port: 5524
    roles:
      - tag: admin
        name: ccadmin
        password: c1oudc0w
    databases:
      - tag: cc
        name: ccdb
        citext: true

  ccdb_ng: *ccdb

  uaadb:
    db_scheme: postgresql
    address: 0.postgres.default.cf.microbosh
    port: 5524
    roles:
      - tag: admin
        name: uaaadmin
        password: c1oudc0w
    databases:
      - tag: uaa
        name: uaadb
        citext: true

  cc_api_version: v2

  cc: &cc
    logging_level: debug
    external_host: api
    srv_api_uri: http://api.your.domain.name
    cc_partition: default
    db_encryption_key: c1oudc0w
    bootstrap_admin_email: admin@your.domain.name
    bulk_api_password: c1oudc0w
    uaa_resource_id: cloud_controller
    staging_upload_user: uploaduser
    staging_upload_password: c1oudc0w
    resource_pool:
      resource_directory_key: cc-resources
      # Local provider when using NFS
      fog_connection:
        provider: Local
    packages:
      app_package_directory_key: cc-packages
    droplets:
      droplet_directory_key: cc-droplets
    default_quota_definition: runaway

  ccng: *cc

  login:
    enabled: false

  uaa:
    url: http://uaa.your.domain.name
    spring_profiles: postgresql
    no_ssl: true
    catalina_opts: -Xmx768m -XX:MaxPermSize=256m
    resource_id: account_manager
    jwt:
      signing_key: |
        -----BEGIN RSA PRIVATE KEY-----
        MIICXAIBAAKBgQDHFr+KICms+tuT1OXJwhCUmR2dKVy7psa8xzElSyzqx7oJyfJ1
        JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMXqHxf+ZH9BL1gk9Y6kCnbM5R6
        0gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBugspULZVNRxq7veq/fzwIDAQAB
        AoGBAJ8dRTQFhIllbHx4GLbpTQsWXJ6w4hZvskJKCLM/o8R4n+0W45pQ1xEiYKdA
        Z/DRcnjltylRImBD8XuLL8iYOQSZXNMb1h3g5/UGbUXLmCgQLOUUlnYt34QOQm+0
        KvUqfMSFBbKMsYBAoQmNdTHBaz3dZa8ON9hh/f5TT8u0OWNRAkEA5opzsIXv+52J
        duc1VGyX3SwlxiE2dStW8wZqGiuLH142n6MKnkLU4ctNLiclw6BZePXFZYIK+AkE
        xQ+k16je5QJBAN0TIKMPWIbbHVr5rkdUqOyezlFFWYOwnMmw/BKa1d3zp54VP/P8
        +5aQ2d4sMoKEOfdWH7UqMe3FszfYFvSu5KMCQFMYeFaaEEP7Jn8rGzfQ5HQd44ek
        lQJqmq6CE2BXbY/i34FuvPcKU70HEEygY6Y9d8J3o6zQ0K9SYNu+pcXt4lkCQA3h
        jJQQe5uEGJTExqed7jllQ0khFJzLMx0K6tj0NeeIzAaGCQz13oo2sCdeGRHO4aDh
        HH6Qlq/6UOV5wP8+GAcCQFgRCcB+hrje8hfEEefHcFpyKH+5g1Eu1k0mLrxK2zd+
        4SlotYRHgPCEubokb2S1zfZDWIXW3HmggnGgM949TlY=
        -----END RSA PRIVATE KEY-----
      verification_key: |
        -----BEGIN PUBLIC KEY-----
        MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHFr+KICms+tuT1OXJwhCUmR2d
        KVy7psa8xzElSyzqx7oJyfJ1JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMX
        qHxf+ZH9BL1gk9Y6kCnbM5R60gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBug
        spULZVNRxq7veq/fzwIDAQAB
        -----END PUBLIC KEY-----
    cc:
      client_secret: c1oudc0w
    admin:
      client_secret: c1oudc0w
    batch:
      username: batchuser
      password: c1oudc0w
    client:
      autoapprove:
        - cf
    clients:
      cf:
        override: true
        authorized-grant-types: password,implicit,refresh_token
        authorities: uaa.none
        scope: cloud_controller.read,cloud_controller.write,openid,password.write,cloud_controller.admin,scim.read,scim.write
        access-token-validity: 7200
        refresh-token-validity: 1209600
    scim:
      users:
      - admin|c1oudc0w|scim.write,scim.read,openid,cloud_controller.admin
      - services|c1oudc0w|scim.write,scim.read,openid,cloud_controller.admin
```


#### Deploy and configure DNS

Speficy the manifest file and execute deploying.

```sh
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh deployment ~/cf.yml
```

Then, deploy it.

```sh
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh deploy
```

You will be able to confirm VMs created for the deployment by the `bosh vms` command.

```sh
BUNDLE_GEMFILE=~/bosh/Gemfile bundle exec bosh vms
```

You can find the IP address of the router of your deployment in the output of the command. Set the address to an A record of your domain name to route requests to your CF instance.




### Setup a Full BOSH (Optional)

#### Sample Templates

Currently the CloudStack CPI does not support VIP networks and Floating IPs. You need some tricks to deploy releases which require floating IPs such as Full BOSH.

For Full BOSH, you need two separate manifest files. One for DNS and another for other jobs.

##### bosh-dns.yml

```yaml
---
name: bosh-dns
director_uuid: <Director UUID>

release:
  name: bosh
  version: latest

compilation:
  workers: 3
  network: default
  reuse_compilation_vms: true
  cloud_properties:
    instance_type: m1.small

update:
  canaries: 1
  canary_watch_time: 3000-120000
  update_watch_time: 3000-120000
  max_in_flight: 4
  max_errors: 1

networks:
  - name: default
    type: dynamic
    cloud_properties:
      security_groups:
        - bosh  # Security group

resource_pools:
  - name: small
    network: default
    size: 1
    stemcell:
      name: bosh-cloudstack-kvm-ubuntu
      version: latest
    cloud_properties:
      instance_type: m1.small

jobs:
  - name: powerdns
    template:
      - powerdns
    instances: 1
    resource_pool: small
    persistent_disk: 40960
    networks:
      - name: default
        default: [dns, gateway]

properties:
  env:

  cloudstack:
    endpoint: <endpoint_url>
    api_key: <app_key>
    secret_access_key: <secret_access_key>
    default_key_name: <ssh_key_name>
    default_security_groups:
      - bosh # Security group
    state_timeout: 600
    stemcell_public_visibility: true
    default_zone: <zone>

  postgres: &bosh_db
    host: 0.postgres.default.bosh.microbosh
    password: bosh
    database: bosh
    user: bosh

  dns:
    address: 198.51.100.89 # Put a random IP address first, and replace the correct address later
    db: *bosh_db
    recursor: 198.51.100.39 # IP address of MicroBOSH
```

#### bosh.yml

```yaml
---
name: bosh
director_uuid: <Director UUID>

release:
  name: bosh
  version: latest

compilation:
  workers: 3
  network: default
  reuse_compilation_vms: true
  cloud_properties:
    instance_type: m1.small

update:
  canaries: 1
  canary_watch_time: 3000-120000
  update_watch_time: 3000-120000
  max_in_flight: 4
  max_errors: 1

networks:
  - name: default
    type: dynamic
    cloud_properties:
      security_groups:
        - bosh

resource_pools:
  - name: small
    network: default
    size: 6
    stemcell:
      name: bosh-cloudstack-kvm-ubuntu
      version: latest
    cloud_properties:
      instance_type: m1.small

  - name: medium
    network: default
    size: 1
    stemcell:
      name: bosh-cloudstack-kvm-ubuntu
      version: latest
    cloud_properties:
      instance_type: m1.medium

jobs:
  - name: nats
    template: nats
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: postgres
    template: postgres
    instances: 1
    resource_pool: small
    persistent_disk: 2048
    networks:
      - name: default
        default: [dns, gateway]

  - name: redis
    template: redis
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: director
    template: director
    instances: 1
    resource_pool: medium
    persistent_disk: 4096
    networks:
      - name: default
        default: [dns, gateway]

  - name: blobstore
    template: blobstore
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: registry
    template: registry
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

  - name: health_monitor
    template: health_monitor
    instances: 1
    resource_pool: small
    networks:
      - name: default
        default: [dns, gateway]

properties:
  env:

  cloudstack:
    endpoint: <endpoint_url>
    api_key: <app_key>
    secret_access_key: <secret_access_key>
    default_key_name: <ssh_key_name>
    default_security_groups:
      - bosh # Security group
    state_timeout: 600
    stemcell_public_visibility: true
    default_zone: <zone>

  nats:
    address: 0.nats.default.bosh.microbosh
    user: nats
    password: nats

  postgres: &bosh_db
    host: 0.postgres.default.bosh.microbosh
    password: bosh
    database: bosh
    user: bosh

  dns:
    address: <ip_address_of_dns_job> # The IP address of the VM deployed with bosh-dns.yml
    db: *bosh_db
    recursor: 198.51.100.39 # IP address of MicroBOSH

  redis:
    address: 0.redis.default.bosh.microbosh
    password: redis

  director:
    name: bosh
    address: 0.director.default.bosh.microbosh
    db: *bosh_db

  blobstore:
    address: 0.blobstore.default.bosh.microbosh
    agent:
      user: agent
      password: agent
    director:
      user: director
      password: director

  registry:
    address: 0.registry.default.bosh.microbosh
    db:
      host: 0.postgres.default.bosh.microbosh
      database: bosh
      password: bosh
    http:
      user: registry
      password: registry

  hm:
    http:
      user: hm
      password: hm
    director_account:
      user: admin
      password: admin
    event_nats_enabled: false
    email_notifications: false
    tsdb_enabled: false
    pagerduty_enabled: false
    varz_enabled: true
```

### Deployment Procedure

1. Deploy bosh-dns.yml
2. Put the IP address of the deployed VM to bosh.yml and bosh-dns.yml
3. Deploy bosh.yml
4. Redeploy bosh-dns.yml

You can find the IP address of deployed VMs by the `bosh status` command.
