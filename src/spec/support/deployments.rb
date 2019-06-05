module Bosh::Spec
  class Deployments
    DEFAULT_DEPLOYMENT_NAME = 'simple'.freeze

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

        'resource_pools' => [],
      }
    end

    def self.cloud_config_with_placeholders
      {
        'azs' => [
          { 'name' => 'z1', 'cloud_properties' => '((/z1_cloud_properties))' },
          { 'name' => 'z2', 'cloud_properties' => '((/z2_cloud_properties))' },
        ],

        'vm_types' => [{
          'name' => 'small',
          'cloud_properties' => {
            'instance_type' => 't2.micro',
            'ephemeral_disk' => '((/ephemeral_disk_placeholder))',
          },
        }, {
          'name' => 'medium',
          'cloud_properties' => {
            'instance_type' => 'm3.medium',
            'ephemeral_disk' => '((/ephemeral_disk_placeholder))',
          },
        }],

        'disk_types' => '((/disk_types_placeholder))',

        'networks' => [{
          'name' => 'private',
          'type' => 'manual',
          'subnets' => '((/subnets_placeholder))',
        }, {
          'name' => 'vip',
          'type' => 'vip',
        }, {
          'name' => 'other',
          'type' => 'manual',
          'subnets' => [{
            'range' => '10.10.0.0/24',
            'gateway' => '10.10.0.1',
            'az' => 'z1',
            'static' => ['10.10.0.62'],
            'dns' => ['10.10.0.2'],
            'cloud_properties' => { 'thing' => '((/z3_variable_name))' },
          }],
        }],

        'compilation' => {
          'workers' => '((/workers_placeholder))',
          'reuse_compilation_vms' => true,
          'az' => 'z1',
          'vm_type' => 'medium',
          'network' => 'private',
        },
      }
    end

    def self.cloud_config_with_cloud_properties_placeholders
      {
        'azs' => [
          {
            'name' => 'z1',
            'cloud_properties' => {
              'secret' => '((/never-log-me))',
            },
          },
        ],
        'vm_types' => [
          {
            'name' => 'small',
            'cloud_properties' => {
              'secret' => '((/never-log-me))',
            },
          },
        ],
        'disk_types' => [
          {
            'name' => 'small',
            'disk_size' => 3000,
            'cloud_properties' => {
              'secret' => '((/never-log-me))',
            },
          },
        ],
        'networks' => [
          {
            'name' => 'private',
            'type' => 'manual',
            'subnets' => [
              {
                'range' => '10.10.0.0/24',
                'gateway' => '10.10.0.1',
                'az' => 'z1',
                'static' => [
                  '10.10.0.62',
                ],
                'dns' => [
                  '10.10.0.2',
                ],
                'cloud_properties' => {
                  'secret' => '((/never-log-me))',
                },
              },
            ],
          },
        ],
        'vm_extensions' => [
          {
            'name' => 'pub-lbs',
            'cloud_properties' => {
              'secret' => '((/never-log-me))',
            },
          },
        ],
        'compilation' => {
          'workers' => 5,
          'reuse_compilation_vms' => true,
          'az' => 'z1',
          'vm_type' => 'small',
          'network' => 'private',
        },
      }
    end

    def self.simple_cloud_config
      minimal_cloud_config.merge(
        'networks' => [network],
        'resource_pools' => [resource_pool],
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
          'subnets' => [subnet('az' => 'z1'),
                        {
                          'range' => '192.168.2.0/24',
                          'gateway' => '192.168.2.1',
                          'dns' => ['192.168.2.1', '192.168.2.2'],
                          'static' => ['192.168.2.10'],
                          'reserved' => [],
                          'cloud_properties' => {},
                          'az' => 'z2',
                        }],
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
        'resource_pools' => [resource_pool],
        'azs' => azs,
        'compilation' => {
          'workers' => 1,
          'network' => 'a',
          'cloud_properties' => {},
          'az' => 'z1',
        },
      )
    end

    def self.runtime_config_latest_release
      {
        'releases' => [{ 'name' => 'bosh-release', 'version' => 'latest' }],
      }
    end

    def self.runtime_config_release_missing
      {
        'releases' => [{ 'name' => 'test_release_2', 'version' => '2' }],
        'addons' => [{ 'name' => 'addon1', 'jobs' => [{ 'name' => 'job_using_pkg_2', 'release' => 'release2' }] }],
      }
    end

    def self.runtime_config_with_addon
      {
        'releases' => [{ 'name' => 'dummy2', 'version' => '0.2-dev' }],
        'addons' => [
          {
            'name' => 'addon1',
            'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }, { 'name' => 'dummy_with_package', 'release' => 'dummy2' }],
            'properties' => { 'dummy_with_properties' => { 'echo_value' => 'addon_prop_value' } },
          },
        ],
      }
    end

    def self.runtime_config_with_addon_includes
      runtime_config_with_addon.merge(
        'addons' => [
          {
            'name' => 'addon1',
            'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }],
            'properties' => { 'dummy_with_properties' => { 'echo_value' => 'prop_value' } },
            'include' => {
              'deployments' => ['dep1'],
              'jobs' => [
                { 'name' => 'foobar', 'release' => 'bosh-release' },
              ],
            },
          },
        ],
      )
    end

    def self.runtime_config_with_addon_excludes
      runtime_config_with_addon.merge(
        'addons' => [
          {
            'name' => 'addon1',
            'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }],
            'properties' => { 'dummy_with_properties' => { 'echo_value' => 'prop_value' } },
            'exclude' => {
              'deployments' => ['dep1'],
              'jobs' => [
                { 'name' => 'foobar', 'release' => 'bosh-release' },
              ],
            },
          },
        ],
      )
    end

    def self.runtime_config_with_addon_includes_stemcell_os
      runtime_config_with_addon.merge(
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
    end

    def self.runtime_config_with_addon_includes_network
      runtime_config_with_addon.merge(
        'addons' => [
          'name' => 'addon1',
          'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy2' }],
          'include' => {
            'networks' => ['a'],
          },
        ],
      )
    end

    def self.runtime_config_with_addon_excludes_lifecycle
      runtime_config_with_addon.merge(
        'addons' => [
          'name' => 'addon1',
          'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy2' }],
          'exclude' => {
            'lifecycle' => 'errand',
          },
        ],
      )
    end

    def self.runtime_config_with_addon_placeholders
      runtime_config_with_addon.merge(
        'addons' => [
          {
            'name' => 'addon1',
            'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => '((/release_name))' }],
            'properties' => { 'dummy_with_properties' => { 'echo_value' => '((/addon_prop))' } },
          },
        ],
      )
    end

    def self.runtime_config_with_job_placeholders
      {
        'releases' => [{ 'name' => '((/release_name))', 'version' => '0.1-dev' }],
        'addons' => [
          {
            'name' => 'addon1',
            'jobs' => [
              {
                'name' => 'job_2_with_many_properties',
                'release' => '((/release_name))',
                'properties' => {
                  'gargamel' => { 'color' => '((/gargamel_colour))' },
                },
              },
            ],
          },
        ],
      }
    end

    def self.runtime_config_with_links
      {
        'releases' => [{ 'name' => 'bosh-release', 'version' => '0+dev.1' }],
        'addons' => [
          {
            'name' => 'addon_job',
            'jobs' => [
              { 'name' => 'addon',
                'release' => 'bosh-release',
                'consumes' => { 'db' => { 'from' => 'db' } } },
            ],
          },
        ],
      }
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

    def self.remote_stemcell_manifest(stemcell_url, stemcell_sha1)
      minimal_manifest.merge(
        'networks' => [{
          'name' => 'a',
          'subnets' => [{
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'static' => ['192.168.1.10'],
            'reserved' => [],
            'cloud_properties' => {},
          }],
        }],

        'compilation' => {
          'workers' => 1,
          'network' => 'a',
          'cloud_properties' => {},
        },

        'resource_pools' => [{
          'name' => 'a',
          'size' => 3,
          'cloud_properties' => {},
          'network' => 'a',
          'stemcell' => {
            'name' => 'ubuntu-stemcell',
            'version' => 1,
            'url' => stemcell_url,
            'sha1' => stemcell_sha1,
          },
        }],
      )
    end

    def self.local_stemcell_manifest(stemcell_path)
      minimal_manifest.merge(
        'networks' => [{
          'name' => 'a',
          'subnets' => [{
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'static' => ['192.168.1.10'],
            'reserved' => [],
            'cloud_properties' => {},
          }],
        }],

        'compilation' => {
          'workers' => 1,
          'network' => 'a',
          'cloud_properties' => {},
        },

        'resource_pools' => [{
          'name' => 'a',
          'size' => 3,
          'cloud_properties' => {},
          'network' => 'a',
          'stemcell' => {
            'name' => 'ubuntu-stemcell',
            'version' => '1',
            'url' => stemcell_path,
          },
        }],
      )
    end

    def self.resource_pool
      {
        'name' => 'a',
        'cloud_properties' => {},
        'stemcell' => {
          'name' => 'ubuntu-stemcell',
          'version' => '1',
        },
        'env' => {
          'bosh' => {
            'password' => 'foobar',
          },
        },
      }
    end

    def self.stemcell
      {
        'alias' => 'default',
        'os' => 'toronto-os',
        'version' => '1',
      }
    end

    def self.vm_type
      {
        'name' => 'vm-type-name',
        'cloud_properties' => {},
      }
    end

    def self.vm_extension
      {
        'name' => 'vm-extension-name',
        'cloud_properties' => { 'my' => 'cloud_property' },
      }
    end

    def self.disk_pool
      {
        'name' => 'disk_a',
        'disk_size' => 123,
      }
    end

    def self.disk_type
      {
        'name' => 'disk_a',
        'disk_size' => 123,
      }
    end

    def self.minimal_manifest
      {
        'name' => 'minimal',

        'releases' => [{
          'name'    => 'test_release',
          'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },
      }
    end

    def self.multiple_release_manifest
      {
        'name' => 'minimal',

        'releases' => [{
          'name' => 'test_release',
          'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
        }, {
          'name' => 'test_release_2',
          'version' => '2' # It's our dummy valid release from spec/assets/test_release_2.tgz
        }],

        'update' => {
          'canaries' => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20,
        },
      }
    end

    def self.test_release_manifest
      minimal_manifest.merge(
        'name' => DEFAULT_DEPLOYMENT_NAME,

        'releases' => [{
          'name'    => 'bosh-release',
          'version' => '0.1-dev',
        }],
      )
    end

    def self.remote_release_manifest(remote_release_url, sha1, version = 'latest')
      minimal_manifest.merge(test_release_job).merge(
        'releases' => [{
          'name'    => 'test_release',
          'version' => version,
          'url' => remote_release_url,
          'sha1' => sha1,
        }],
      )
    end

    def self.local_release_manifest(local_release_path, version = 'latest')
      minimal_manifest.merge(test_release_job).merge(
        'releases' => [{
          'name'    => 'test_release',
          'version' => version,
          'url' => local_release_path,
        }],
      )
    end
  end
end
