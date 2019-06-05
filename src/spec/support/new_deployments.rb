module Bosh::Spec
  class NewDeployments
    DEFAULT_DEPLOYMENT_NAME = 'simple'.freeze
    DISK_TYPE = {
      'name' => 'default',
      'disk_size' => 1024,
      'cloud_properties' => {},
    }.freeze

    def self.simple_cloud_config
      minimal_cloud_config.merge(
        'networks' => [network],
        'vm_types' => [vm_type],
      )
    end

    def self.minimal_cloud_config
      {
        'networks' => [{
          'name' => 'a',
          'subnets' => [],
        }],

        'compilation' => {
          'workers' => 1,
          'network' => 'a',
          'cloud_properties' => {},
        },

        'vm_types' => [],
      }
    end

    def self.network(options = {})
      {
        'name' => 'a',
        'subnets' => [subnet],
      }.merge!(options)
    end

    def self.subnet(options = {})
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1', '192.168.1.2'],
        'static' => ['192.168.1.10'],
        'reserved' => [],
        'cloud_properties' => {},
      }.merge!(options)
    end

    def self.vm_type
      {
        'name' => 'a',
        'cloud_properties' => {},
      }
    end

    def self.vm_extension
      {
        'name' => 'vm-extension-name',
        'cloud_properties' => { 'my' => 'cloud_property' },
      }
    end

    def self.simple_errand_instance_group
      {
        'name' => 'fake-errand-name',
        'jobs' => [
          {
            'release' => 'bosh-release',
            'name' => 'errand1',
            'properties' => {
              'errand1' => {
                'exit_code' => 0,
                'stdout' => 'fake-errand-stdout',
                'stderr' => 'fake-errand-stderr',
                'run_package_file' => true,
              },
            },
          },
        ],
        'stemcell' => 'default',
        'lifecycle' => 'errand',
        'vm_type' => 'a',
        'instances' => 1,
        'networks' => [{ 'name' => 'a' }],
        'env' => {},
      }
    end

    def self.simple_instance_group(opts = {})
      instance_group_hash = {
        'name' => opts.fetch(:name, 'foobar'),
        'stemcell' => opts[:stemcell] || 'default',
        'vm_type' => opts.fetch(:vm_type, 'a'),
        'instances' => opts.fetch(:instances, 3),
        'networks' => [{ 'name' => opts.fetch(:network_name, 'a') }],
        'properties' => {},
        'jobs' => opts.fetch(
          :jobs, [{
            'name' => opts.fetch(:job_name, 'foobar'),
            'release' => opts.fetch(:job_release, 'bosh-release'),
            'properties' => {},
          }]
        ),
      }

      instance_group_hash['env'] = opts[:env] if opts.key?(:env)
      instance_group_hash['persistent_disk_type'] = opts[:persistent_disk_type] if opts[:persistent_disk_type]
      instance_group_hash['networks'].first['static_ips'] = opts[:static_ips] if opts.key?(:static_ips)
      instance_group_hash['azs'] = opts[:azs] if opts.key?(:azs)
      instance_group_hash['properties'] = opts[:properties] if opts.key?(:properties)

      if opts.key?(:vm_resources)
        instance_group_hash.delete('vm_type')
        instance_group_hash['vm_resources'] = opts[:vm_resources]
      end

      instance_group_hash
    end

    def self.minimal_manifest
      {
        'name' => 'minimal',

        'releases' => [{
          'name'    => 'test_release',
          'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
        }],

        'stemcells' => [{
          'alias' => 'default',
          'os' => 'toronto-os',
          'version' => 'latest',
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },
      }
    end

    def self.minimal_manifest_with_ubuntu_stemcell
      minimal_manifest.merge(
        'stemcells' => [
          {
            'name' => 'ubuntu-stemcell',
            'version' => '1',
            'alias' => 'default',
          },
        ],
      )
    end

    def self.manifest_with_release
      minimal_manifest.merge(
        'name' => DEFAULT_DEPLOYMENT_NAME,
        'releases' => [{
          'name' => 'bosh-release',
          'version' => '0.1-dev',
        }],
      )
    end

    def self.test_release_manifest_with_stemcell
      minimal_manifest_with_ubuntu_stemcell.merge(
        'name' => DEFAULT_DEPLOYMENT_NAME,
        'releases' => [{
          'name' => 'bosh-release',
          'version' => '0.1-dev',
        }],
      )
    end

    def self.simple_manifest_with_instance_groups(opts = {})
      test_release_manifest_with_stemcell.merge(
        'instance_groups' => [simple_instance_group(opts)],
      )
    end

    def self.simple_manifest_with_instance_groups_and_vm_resources
      test_release_manifest_with_stemcell.merge(
        'instance_groups' => [
          simple_instance_group(vm_resources: { 'cpu' => 2, 'ram' => 1024, 'ephemeral_disk_size' => 10 }),
        ],
      )
    end

    def self.manifest_with_errand
      manifest = simple_manifest_with_instance_groups.merge('name' => 'errand')
      manifest['instance_groups'].find { |instance_group| instance_group['name'] == 'foobar' }['instances'] = 1
      manifest['instance_groups'] << simple_errand_instance_group
      manifest
    end

    def self.manifest_errand_with_placeholders
      manifest = manifest_with_errand
      manifest['instance_groups'][1]['jobs'].first['properties']['errand1']['stdout'] = '((placeholder))'
      manifest.merge('env' => {
        'bosh' => {
          'password' => '((errand_password))',
        },
      })
    end

    def self.test_release_instance_group
      {
        'instance_group' => [{
          'name' => 'instance_group',
          'jobs' => [{ 'name' => 'job_using_pkg_1' }],
          'instances' => 1,
          'resource_pool' => 'a',
          'networks' => [{ 'name' => 'a' }],
        }],
      }
    end

    def self.remote_release_manifest(remote_release_url, sha1, version = 'latest')
      minimal_manifest_with_ubuntu_stemcell.merge(test_release_instance_group).merge(
        'releases' => [{
          'name'    => 'test_release',
          'version' => version,
          'url' => remote_release_url,
          'sha1' => sha1,
        }],
      )
    end

    def self.local_release_manifest(local_release_path, version = 'latest')
      minimal_manifest_with_ubuntu_stemcell.merge(test_release_instance_group).merge(
        'releases' => [{
          'name'    => 'test_release',
          'version' => version,
          'url' => local_release_path,
        }],
      )
    end

    def self.simple_cloud_config_with_multiple_azs_and_cpis
      cloud_config = simple_cloud_config_with_multiple_azs

      cloud_config['azs'].each_index do |i|
        cloud_config['azs'][i]['cpi'] = "cpi-name#{i + 1}"
      end

      cloud_config
    end

    def self.simple_cloud_config_with_multiple_azs
      networks = [
        {
          'name' => 'a',
          'subnets' => [
            subnet('az' => 'z1'),
            {
              'range' => '192.168.2.0/24',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => ['192.168.2.10'],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'z2',
            },
          ],
        },
      ]

      azs = [
        {
          'name' => 'z1',
          'cloud_properties' => { 'a' => 'b' },
        },
        {
          'name' => 'z2',
          'cloud_properties' => { 'a' => 'b' },
        },
      ]
      minimal_cloud_config.merge(
        'networks' => networks,
        'vm_types' => [vm_type],
        'azs' => azs,
        'compilation' => {
          'workers' => 1,
          'network' => 'a',
          'cloud_properties' => {},
          'az' => 'z1',
        },
      )
    end

    def self.simple_runtime_config(release = 'test_release_2', version = '2')
      {
        'releases' => [{ 'name' => release, 'version' => version }],
      }
    end

    def self.single_cpi_config(name = 'cpi-name1', properties = { 'somekey' => 'someval' }, exec_path = nil)
      cpi_config = {
        'cpis' => [
          {
            'name' => name,
            'type' => 'cpi-type',
            'properties' => properties,
          },
        ],
      }
      cpi_config['cpis'].first['exec_path'] = exec_path unless exec_path.nil?
      cpi_config
    end

    def self.multi_cpi_config(exec_path = nil)
      cpi_config = {
        'cpis' => [
          {
            'name' => 'cpi-name1',
            'type' => 'cpi-type',
            'properties' => {
              'somekey' => 'someval',
            },
          },
          {
            'name' => 'cpi-name2',
            'type' => 'cpi-type2',
            'properties' => {
              'somekey2' => 'someval2',
            },
          },
        ],
      }
      cpi_config['cpis'].each { |cpi| cpi['exec_path'] = exec_path } unless exec_path.nil?
      cpi_config
    end

    def self.multi_cpi_config_with_variables(exec_path = nil)
      cpi_config = {
        'cpis' => [
          {
            'name' => 'cpi-name1',
            'type' => 'cpi-type1',
            'properties' => {
              'someKeyFoo1' => '((/cpi-someFooVal1-var))',
              'someKeyBar1' => '((/cpi-someBarVal1-var))',
            },
          },
          {
            'name' => 'cpi-name2',
            'type' => 'cpi-type2',
            'properties' => {
              'someKeyFoo2' => '((/cpi-someFooVal2-var))',
              'someKeyBar2' => '((/cpi-someBarVal2-var))',
            },
          },
        ],
      }
      cpi_config['cpis'].each { |cpi| cpi['exec_path'] = exec_path } unless exec_path.nil?
      cpi_config
    end

    def self.instance_group_with_many_jobs(options = {})
      {
        'name' => options.fetch(:name),
        'jobs' => options.fetch(:jobs),
        'vm_type' => 'a',
        'instances'     => options.fetch(:instances, 3),
        'networks'      => [{ 'name' => 'a' }],
        'properties'    => options.fetch(:properties, {}),
        'stemcell' => options.fetch(:stemcell, 'default'),
      }
    end

    def self.test_deployment_manifest
      {
        'name' => 'test_deployment',
        'releases' => [{
          'name'    => 'test_release',
          'version' => '1',
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },

        'stemcells' => [{
          'alias' => 'default',
          'os' => 'toronto-os',
          'version' => '1',
        }],
      }
    end

    def self.test_deployment_manifest_with_job(job_name, release)
      test_deployment_manifest.merge(
        'instance_groups' => [{
          'name'          => job_name,
          'jobs' => [{
            'name' => job_name,
            'release' => release,
          }],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
          'stemcell' => 'default',
        }],
      )
    end

    def self.test_deployment_manifest_referencing_multiple_releases
      {
        'name' => 'multiple_release_deployment',

        'releases' => [{
          'name'    => 'test_release',
          'version' => '1',
        }, {
          'name'    => 'test_release_a',
          'version' => '1',
        }],

        'stemcells' => [{
          'alias' => 'default',
          'os' => 'toronto-os',
          'version' => '1',
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },
        'instance_groups' => [{
          'name'          => 'instance_group_name',
          'jobs' => [{
            'name'    => 'job_using_pkg_1_and_2',
            'release' => 'test_release',
          }, {
            'name'    => 'job_using_pkg_5',
            'release' => 'test_release_a',
          }],
          'vm_type' => 'a',
          'instances'     => 1,
          'networks'      => [{ 'name' => 'a' }],
          'stemcell' => 'default',
        }],
      }
    end

    def self.stemcell_os_specific_addon_manifest
      manifest_with_release.merge(
        'instance_groups' => [
          simple_instance_group(vm_type: 'a', name: 'has-addon-vm', instances: 1, stemcell: 'toronto'),
          simple_instance_group(vm_type: 'b', name: 'no-addon-vm', instances: 1, stemcell: 'centos'),
        ],
      )
    end

    def self.simple_os_specific_cloud_config
      vm_types = [
        {
          'name' => 'a',
          'cloud_properties' => {},
        },
        {
          'name' => 'b',
          'cloud_properties' => {},
        },
      ]
      minimal_cloud_config.merge(
        'networks' => [network],
        'vm_types' => vm_types,
      )
    end

    def self.multiple_release_manifest
      {
        'name' => 'minimal',

        'releases' => [{
          'name'    => 'test_release',
          'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
        }, {
          'name'    => 'test_release_2',
          'version' => '2' # It's our dummy valid release from spec/assets/test_release_2.tgz
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },
        'stemcells' => [{
          'alias' => 'default',
          'os' => 'toronto-os',
          'version' => 'latest',
        }],
      }
    end

    def self.manifest_with_addons
      minimal_manifest.merge(
        'name' => DEFAULT_DEPLOYMENT_NAME,
        'releases' => [
          {
            'name' => 'bosh-release',
            'version' => '0.1-dev',
          },
          { 'name' => 'dummy2',
            'version' => '0.2-dev' },
        ],
        'instance_groups' => [{
          'name' => 'foobar',
          'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
          'instances' => 1,
          'vm_type' => 'a',
          'networks' => [{ 'name' => 'a' }],
          'stemcell' => 'default',
        }],
        'addons' => [{
          'name' => 'addon1',
          'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }],
          'properties' => { 'dummy_with_properties' => { 'echo_value' => 'prop_value' } },
        }],
      )
    end

    def self.complex_manifest_with_addon
      manifest = minimal_manifest.merge(
        'name' => DEFAULT_DEPLOYMENT_NAME,
        'releases' => [
          {
            'name' => 'bosh-release',
            'version' => '0.1-dev',
          },
          { 'name' => 'dummy2',
            'version' => '0.2-dev' },
        ],
        'instance_groups' => [
          simple_instance_group(
            vm_type: 'b',
            name: 'has-rc-addon-vm',
            jobs: [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
            instances: 1,
            stemcell: 'centos',
          ),
          simple_instance_group(
            vm_type: 'a',
            name: 'has-depl-rc-addons-vm',
            jobs: [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
            instances: 1,
          ),
          simple_instance_group(
            vm_type: 'a',
            name: 'has-depl-addon-vm',
            jobs: [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }],
            instances: 1,
          ),
        ],
        'addons' => [
          'name' => 'addon1',
          'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy2' }],
          'include' => {
            'stemcell' => [
              { 'os' => 'toronto-os' },
            ],
          },
        ],
      )
      manifest['stemcells'] << {
        'alias' => 'centos',
        'os' => 'toronto-centos',
        'version' => 'latest',
      }
      manifest
    end

    def self.manifest_with_errand_on_service_instance
      manifest = manifest_with_release
      manifest['instance_groups'] = [service_instance_group_with_errand]
      manifest
    end

    def self.service_instance_group_with_errand
      {
        'name' => 'service_with_errand',
        'jobs' => [{
          'release' => 'bosh-release',
          'name' => 'errand1',
          'properties' => {
            'errand1' => {
              'exit_code' => 0,
              'stdout' => 'fake-errand-stdout-service',
              'stderr' => 'fake-errand-stderr-service',
              'run_package_file' => true,
            },
          },
        }],
        'lifecycle' => 'service',
        'vm_type' => 'a',
        'instances' => 1,
        'networks' => [{ 'name' => 'a' }],
        'stemcell' => 'default',
      }
    end

    def self.disk_type
      {
        'name' => 'disk_a',
        'disk_size' => 123,
      }
    end

    def self.resurrection_config_enabled
      {
        'rules' => [
          {
            'enabled' => true,
            'include' => {
              'deployments' => ['simple_enabled'],
              'instance_groups' => ['foobar'],
            },
          },
        ],
      }
    end

    def self.resurrection_config_disabled
      {
        'rules' => [
          {
            'enabled' => false,
            'include' => {
              'deployments' => ['simple_disabled'],
            },
            'exclude' => {
              'instance_groups' => ['foobar_without_packages'],
            },
          },
        ],
      }
    end
  end
end
