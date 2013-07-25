require 'rspec'
require 'yaml'
require 'common/properties'

describe 'director.yml.erb' do

  def eval_template(erb, context)
    ERB.new(erb).result(context.get_binding)
  end

  def make(spec)
    Bosh::Common::TemplateEvaluationContext.new(spec)
  end

  let(:spec) {
    y = <<-eos
---
name: vpc-bosh-ssweda
director_uuid: 661186aa-579c-4ea1-9989-6732ee2f4ac1
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
      subnet: subnet-a2c7bccd
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
    version: 748
  network: default
  size: 2
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
#  - blobstore
  - redis
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
    - 54.208.53.13
- name: dns
  template:
  - powerdns
  instances: 1
  resource_pool: default
  persistent_disk: 2048
  networks:
  - name: default
    default:
    - dns
    - gateway
    static_ips:
    - 10.10.0.8
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
    provider: s3
    bucket_name: ssweda-cf-app-com-bosh-blobstore
    access_key_id: AKIAIJZZMW3VZZUUBHZA
    secret_access_key: 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
#    address: 10.10.0.7
#    port: 25251
#    backend_port: 25552
#    agent:
#      user: agent
#      password: ldsjlkadsfjlj
#    director:
#      user: director
#      password: DirectoR

  networks:
    apps: default
    management: default
  nats:
    user: nats
    password: 0b450ada9f830085e2cdeff6
    address: 10.10.0.7
    port: 4222
  mysql: &70160752896000
    adapter: mysql2
    user: ube0cd70a8ccb6c
    password: p400fb93f7b9da033f933b6777943257d
    host: bosh.cunxbn9pfme2.us-east-1.rds.amazonaws.com
    port: 3306
    database: bosh
  redis:
    address: 127.0.0.1
    port: 25255
    password: R3d!S
  director:
    backup_destination:
      provider: s3
      bucket_name: ssweda-cf-app-com-bosh-blobstore
      access_key_id: AKIAIJZZMW3VZZUUBHZA
      secret_access_key: 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

    name: vpc-bosh-ssweda
    address: 10.10.0.7
    port: 25555
    encryption: false
    db: *70160752896000
    ssl:
      key: ! '-----BEGIN RSA PRIVATE KEY-----

        MIIEpAIBAAKCAQEAxdvXJ1VCZPCBOKppVCww0vJpIzCGMhNhlALNGTQIsRxzYmIG

        Z6VgunnPf9+zixM0Xjrol6FTai3rzFOTTcOXAz5y8C6A/5usU7NRihKA/6coOBlw

        w4n8gqk11e77yu7bYvTMf+a+6FlqFRKTZxc/5v5pDyfOHwc6lT6GnvLFC7F2TluG

        EzGElL52dnFrzygMi5O/L2cfRBMasnoQxUOmI5bRz9ZNGPutEvhigVCs3q36Q/D9

        I56R/LOwXjgGUtM/XQkvxg/OCgSOxeHcTT6p1dSaP7AZvKljiYoXfqhxjHLaggg6

        dqDa8MCd6wAAe+0S5Dtg7BZTpBIluvtrTDf/JQIDAQABAoIBAFDbHDuore9OEaC0

        k0KgpHswMSL+S3jfTrsLwgEQsJSgSc7kvDVS8gqCiPd61YZ6HKZ9cFu2w73ackgX

        x1S6H1ZmCNZ6SqEqXuv9lc7U7P6MsvTqAJkIJLbIq4V3mlI99k2kOIX0KAQPtjhS

        VQaGC8k8InbdD3DCpYAkAyOlljzGWc3HmT8wAEfopCRwLzxPBPnQyDnWihuYxCsL

        DO3gnNj5YXXTPvNsPiIwrNRk/TW8f5eQCC4ZQn0PZkH7XqVD4t892aT2hk2Ntk3L

        TNVhDqyZEwM3i7HGhR4+sjMT7SpbjFWICZ2XOHeTf0H5ctY2UjdmJuo1zDWuw9Rm

        kVHUH2kCgYEA+pv9HDpEo3jR36Pweb0rRvmNAY398sEtCcTLTsZixeKd4bpcsiKX

        Fb4oQKmYgmSRAPt+lc5S6MMwdEX+HSYGzGfQxUTgrzpW25OqLyJc8IcNCaNCYuBu

        YPPWJAv8IrRitQcV2s+Vd93+e2RVGolxwygidfBqr6ZKkGPEg9pGxmsCgYEAyh1f

        x7S0hsy7PzKB+yVyRgzH67xNNKxRTCL4VzKJrMs+7BOr1pU/FlLRLITd3nqOQBLn

        Iu4f7yI1rquugFlCq1L2/PRiJshMkPY2Rl4AotQ9bUeK1yMFFzljHmM5nvFeGafK

        3cXkT4cbTyaicMys+WJvAAwCS53vaM4om2SCFK8CgYEAkMQ/SGkYcV4/znLDXW+7

        ajqKC9XcVrjkrXny/8R2Fl28WkLvfS+iGztHwWK26MvzP6AIFb2kAzWN7fzouCnZ

        T4bBANOy/0YyGpGIg8XT7lX1YBXhKYEAAh2ZHCWYNuwBARXguA+mBiJE+T6SMswm

        3Vd34K1K08C53gLj6E7VB5UCgYEAmhs/lpQQOeAMvakTNp1cvlCsdvACpjDlY/oe

        BM6B7wChn3t4QItXqPvIhftg+GvV3sEK/7U1IC6jY+V/jlmA3gTKUiE8XXnH95fj

        1k+CiKTvmU09bcBD92tISjk6DBjZuRIZOnPTG1hW2EkK/prxIM2O+Sgu790iWHUo

        vSMrk/0CgYAghAs2klocdQ7qXJZdfKKyIoP3E2Ri9EtdHnW5SRirPF1LU0jDku82

        7tuAOKsVL/wgxA4iU4z3ItPdV3VLCfu8j4wc2Y/+rg40JtucDofRmo/n0Wje9XqZ

        TIK5ocTXV23o7xgPY5jaJ0xKJsYfx+zFzlrEfE2tj5xi8CEFt5dYrw==

        -----END RSA PRIVATE KEY-----

'
      cert: ! '-----BEGIN CERTIFICATE-----

        MIIC8zCCAdugAwIBAgIBADANBgkqhkiG9w0BAQUFADA9MQswCQYDVQQGEwJVUzEQ

        MA4GA1UECgwHUGl2b3RhbDEcMBoGA1UEAwwTKi5zc3dlZGEuY2YtYXBwLmNvbTAe

        Fw0xMzA2MTkyMjE4MDhaFw0xNjA2MTkyMjE4MDhaMD0xCzAJBgNVBAYTAlVTMRAw

        DgYDVQQKDAdQaXZvdGFsMRwwGgYDVQQDDBMqLnNzd2VkYS5jZi1hcHAuY29tMIIB

        IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxdvXJ1VCZPCBOKppVCww0vJp

        IzCGMhNhlALNGTQIsRxzYmIGZ6VgunnPf9+zixM0Xjrol6FTai3rzFOTTcOXAz5y

        8C6A/5usU7NRihKA/6coOBlww4n8gqk11e77yu7bYvTMf+a+6FlqFRKTZxc/5v5p

        DyfOHwc6lT6GnvLFC7F2TluGEzGElL52dnFrzygMi5O/L2cfRBMasnoQxUOmI5bR

        z9ZNGPutEvhigVCs3q36Q/D9I56R/LOwXjgGUtM/XQkvxg/OCgSOxeHcTT6p1dSa

        P7AZvKljiYoXfqhxjHLaggg6dqDa8MCd6wAAe+0S5Dtg7BZTpBIluvtrTDf/JQID

        AQABMA0GCSqGSIb3DQEBBQUAA4IBAQA4TGu/xRMMT4PprvQgmTbfFvdtXNLP4lHo

        fAEkawU9Dm0KUjegvbdMoBbPDlZ8wBW0Bo/OuOMO/qCii0dJ1S5EEI7QRmwFTA+O

        4tAn5koBWv203JBTQ38pO1uLGtS6e2asVFVZF0aRDKPuOwaezuc9UA2AViTRaTrr

        dVQoAReArqlNDpVZDY/byG2jzAHdNQZDvPKVTMwrBBAA7haxt7rYyl5EX6dkpT+K

        yI8QR9qov4gqPH3Sbsc1HzKSWhc7KP6jHUvX0C/YYzsQtzwSwZqrZsBEs3WtJHdM

        YP6crEyQ/HAnd3BMk4Uef5q0D+ddDaKTPyev3eA2npuZo+HyGOX7

        -----END CERTIFICATE-----

'
  hm:
    http:
      port: 25923
      user: admin
      password: admin
    director_account:
      user: hm
      password: X+DalLwxvxJGn6kfbiAIYQ==
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
    db: *70160752896000
    http:
      port: 25777
      user: awsreg
      password: awsreg
  aws:
    access_key_id: AKIAIJZZMW3VZZUUBHZA
    secret_access_key: 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
    region: us-east-1
    default_key_name: bosh
    ec2_endpoint: ec2.us-east-1.amazonaws.com
    default_security_groups:
    - bosh
  dns:
    address: 10.10.0.8
    db: *70160752896000
    recursor: 208.67.220.220
  compiled_package_cache:
    provider: s3
    options:
      access_key_id: AKIAJMYWZGJVR7YFXTKA
      secret_access_key: 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
      bucket_name: bosh-global-package-cache


eos
    p YAML.load(y)
    YAML.load(y)
  }

  xit 'should make kittens cry' do
    #spec = {}
    #Bosh::Common::TemplateEvaluationContext.new(spec)
    erb_template = File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb')
    p erb_template

    p eval_template(File.read(erb_template), make(spec))


    #To change this template use File | Settings | File Templates.
    #true.should == false
  end
end