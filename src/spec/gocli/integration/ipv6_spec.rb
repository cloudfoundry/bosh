require_relative '../spec_helper'

describe 'ipv6', type: :integration do
  with_reset_sandbox_before_each

  it 'allows jobs to be deployed with ipv6 addresses' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [
      Bosh::Spec::Deployments.simple_job(name: 'without_static_ips'),
      Bosh::Spec::Deployments.simple_job(name: 'with_static_ips')
    ]
    manifest_hash['jobs'][0]['instances'] = 2
    manifest_hash['jobs'][0]['networks'] = [{'name' => 'ipv6'}]
    manifest_hash['jobs'][1]['instances'] = 1
    manifest_hash['jobs'][1]['networks'] = [{'name' => 'ipv6', 'static_ips' => ['fe80::8']}]

    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config['networks'] << {
      'name' => 'ipv6',
      'subnets' => [{
        'range' => 'fe80::/64',
        'gateway' => 'fe80::1',
        'dns' => ['2001:4860:4860::8844', '2001:4860:4860::8888'],
        'static' => ['fe80::8'],
        'reserved' => ['fe80::2-fe80::6'],
        'cloud_properties' => {},
      }],
    }

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    expect_running_vms_with_names_and_count('without_static_ips' => 2, 'with_static_ips' => 1)

    testing 'instances to have ipv6 addresses returned from api' do
      instances = director.instances

      expect(instances.select{ |i| i.job_name == 'without_static_ips'}.map(&:ips).flatten).to match_array(
        ['fe80:0000:0000:0000:0000:0000:0000:0007', 'fe80:0000:0000:0000:0000:0000:0000:0009'])

      expect(instances.select{ |i| i.job_name == 'with_static_ips'}.map(&:ips).flatten).to match_array(
        ['fe80:0000:0000:0000:0000:0000:0000:0008'])
    end

    testing 'cpi to receive ipv6 addresses in create_vm invocations' do
      invocations = current_sandbox.cpi.invocations.select { |i| i.method_name == 'create_vm' }

      expect(invocations.map { |i| i.inputs['networks'] }).to match_array([
        { # compilation VM
          'a' => {
            'type' => 'manual',
            'ip' => '192.168.1.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
          }
        },
        { # compilation VM
          'a' => {
            'type' => 'manual',
            'ip' => '192.168.1.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
          }
        },
        {
          'ipv6' => {
            'type' => 'manual',
            'ip' => 'fe80:0000:0000:0000:0000:0000:0000:0007',
            'netmask' => 'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['2001:4860:4860:0000:0000:0000:0000:8844', '2001:4860:4860:0000:0000:0000:0000:8888'],
            'gateway' => 'fe80:0000:0000:0000:0000:0000:0000:0001',
          }
        },
        {
          'ipv6' => {
            'type' => 'manual',
            'ip' => 'fe80:0000:0000:0000:0000:0000:0000:0008',
            'netmask' => 'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['2001:4860:4860:0000:0000:0000:0000:8844', '2001:4860:4860:0000:0000:0000:0000:8888'],
            'gateway' => 'fe80:0000:0000:0000:0000:0000:0000:0001',
          }
        },
        {
          'ipv6' => {
            'type' => 'manual',
            'ip' => 'fe80:0000:0000:0000:0000:0000:0000:0009',
            'netmask' => 'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['2001:4860:4860:0000:0000:0000:0000:8844', '2001:4860:4860:0000:0000:0000:0000:8888'],
            'gateway' => 'fe80:0000:0000:0000:0000:0000:0000:0001',
          }
        }
      ])
    end

    testing 'rendered job templates to include ipv6 addresses' do
      instance = director.instance('with_static_ips', '0')
      template = instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('spec.ip=fe80:0000:0000:0000:0000:0000:0000:0008')
      expect(template).to include('spec.address=fe80:0000:0000:0000:0000:0000:0000:0008')

      instance = director.instance('without_static_ips', '0')
      template = instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to match(/spec.ip=fe80:0000:0000:0000:0000:0000:0000:000[79]/)
      expect(template).to match(/spec.address=fe80:0000:0000:0000:0000:0000:0000:000[79]/)
    end
  end

  def testing(str); yield; end
end
