module Bosh::Spec
  class Deployments
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

    def self.simple_cloud_config
      minimal_cloud_config.merge({
          'networks' => [network],
          'resource_pools' => [resource_pool]
        })
    end

    def self.simple_runtime_config
      {
        'releases' => [{"name" => 'test_release_2', "version" => "2"}]
      }
    end

    def self.runtime_config_latest_release
      {
        'releases' => [{"name" => 'test_release_2', "version" => "latest"}]
      }
    end

    def self.runtime_config_release_missing
      {
        'releases' => [{"name" => 'test_release_2', "version" => "2"}],
        'addons' => [{"name" => 'addon1', "jobs" => [{"name" => "job_using_pkg_2", "release" => "release2"}]}]
      }
    end

    def self.runtime_config_with_addon
      {
        'releases' => [{"name" => 'dummy2', "version" => "0.2-dev"}],
        'addons' => [
        {
          "name" => 'addon1',
          "jobs" => [{"name" => "dummy_with_properties", "release" => "dummy2"}],
          'properties' => {'dummy_with_properties' => {'echo_value' => 'prop_value'}}
        }]
      }
    end

    def self.runtime_config_with_links
      {
        'releases' => [{"name" => 'bosh-release', "version" => "0+dev.1"}],
        'addons' => [
            {
                'name' => 'addon_job',
                'jobs' => [
                    {'name' => 'addon',
                     'release' => 'bosh-release',
                     'consumes' => {'db' => {'from' => 'db'}}
                    }
                ]
            }
        ]
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

    def self.remote_stemcell_manifest(stemcell_url, stemcell_sha1)
      minimal_manifest.merge(
      {
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
      })
    end

    def self.local_stemcell_manifest(stemcell_path)
      minimal_manifest.merge(
      {
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
      })
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
            'password' => 'foobar'
          }
        }
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
          'cloud_properties' => {},
      }
    end

    def self.disk_pool
      {
        'name' => 'disk_a',
        'disk_size' => 123
      }
    end

    def self.disk_type
      {
        'name' => 'disk_a',
        'disk_size' => 123
      }
    end

    def self.minimal_manifest
      {
        'name' => 'minimal',
        'director_uuid'  => 'deadbeef',

        'releases' => [{
          'name'    => 'test_release',
          'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
        }],

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20
        }
      }
    end

    def self.dummy_job
      {
        'name' => 'dummy',
        'templates' => [{'name'=> 'dummy', 'release' => 'dummy'}],
        'resource_pool' => 'a',
        'networks' => [{'name' => 'a'}],
        'instances' => 1
      }
    end

    def self.dummy_deployment
      {
        'name' => 'dummy',
        'director_uuid'  => 'deadbeef',

        'releases' => [{
          'name'    => 'dummy',
          'version' => '0.2-dev' # It's our dummy valid release from spec/assets/dummy-release.tgz
        }],

        'update' => {
            'canaries'          => 2,
            'canary_watch_time' => 4000,
            'max_in_flight'     => 1,
            'update_watch_time' => 20
        },

        'jobs' => [self.dummy_job]
      }
    end

    def self.manifest_with_jobs
      {
        'name' => 'minimal',
        'director_uuid' => 'deadbeef',

        'releases' => [{
            'name' => 'appcloud',
            'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
          }],

        'update' => {
          'canaries' => 2,
          'canary_watch_time' => 4000,
          'max_in_flight' => 1,
          'update_watch_time' => 20
        },

        'jobs' => [{
            'name' => 'cacher',
            'templates' => [{
                'name' => 'cacher',
                'release' => 'appcloud'
              }],
            'resource_pool' => 'a',
            'instances' => 3,
            'networks' => [{'name' => 'a'}],
          }]
      }
    end

    def self.test_deployment_manifest
      {
          'name' => 'test_deployment',
          'director_uuid'  => 'deadbeef',

          'releases' => [{
                             'name'    => 'test_release',
                             'version' => '1'
                         }],

          'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
          }
      }
    end

    def self.test_deployment_manifest_with_job(job_name)
      test_deployment_manifest.merge(
        {
          'jobs' => [{
              'name'          => job_name,
              'templates'     => [{
                                      'name'    => job_name
                                  }],
              'resource_pool' => 'a',
              'instances'     => 1,
              'networks'      => [{ 'name' => 'a' }],
          }]
        }
      )
    end

    def self.test_deployment_manifest_referencing_multiple_releases
      {
          'name' => 'multiple_release_deployment',
          'director_uuid'  => 'deadbeef',

          'releases' => [{
                             'name'    => 'test_release',
                             'version' => '1'
                         },{
                             'name'    => 'test_release_a',
                             'version' => '1'
                         }],

          'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
          },
          'jobs' => [{
                         'name'          => 'job_name',
                         'templates'     => [{
                                                 'name'    => 'job_using_pkg_1_and_2',
                                                 'release' => 'test_release'
                                             },{
                                                 'name'    => 'job_using_pkg_5',
                                                 'release' => 'test_release_a'
                                             }],
                         'resource_pool' => 'a',
                         'instances'     => 1,
                         'networks'      => [{ 'name' => 'a' }],
                     }]
      }
    end

    def self.minimal_legacy_manifest
      simple_cloud_config.merge(
      {
          'name' => 'minimal_legacy_manifest',
          'director_uuid'  => 'deadbeef',

          'releases' => [{
               'name'    => 'test_release',
               'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
           }],

          'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
          }
      })
    end

    def self.multiple_release_manifest
      {
          'name' => 'minimal',
          'director_uuid'  => 'deadbeef',

          'releases' => [{
               'name'    => 'test_release',
               'version' => '1' # It's our dummy valid release from spec/assets/test_release.tgz
           },{
               'name'    => 'test_release_2',
               'version' => '2' # It's our dummy valid release from spec/assets/test_release_2.tgz
           }],

          'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
          }
      }
    end

    def self.legacy_manifest
      simple_cloud_config.merge(simple_manifest)
    end

    def self.test_release_manifest
      minimal_manifest.merge(
        'name' => 'simple',

        'releases' => [{
          'name'    => 'bosh-release',
          'version' => '0.1-dev',
        }]
      )
    end

    def self.simple_manifest
      test_release_manifest.merge({
        'jobs' => [simple_job]
      })
    end

    def self.remote_release_manifest(remote_release_url, sha1, version='latest')
      minimal_manifest.merge({
          'jobs' => [
            {
              'name' => 'job',
              'templates' => [{ 'name' => 'job_using_pkg_1' }],
              'instances' => 1,
              'resource_pool' => 'a',
              'networks' => [{'name' => 'a'}]
            }
          ],
          'releases' => [{
              'name'    => 'test_release',
              'version' => version,
              'url' => remote_release_url,
              'sha1' => sha1
            }]
        })
    end

    def self.local_release_manifest(local_release_path, version = 'latest')
      minimal_manifest.merge({
          'jobs' => [
            {
              'name' => 'job',
              'templates' => [{ 'name' => 'job_using_pkg_1' }],
              'instances' => 1,
              'resource_pool' => 'a',
              'networks' => [{'name' => 'a'}]
            }
          ],
          'releases' => [{
              'name'    => 'test_release',
              'version' => version,
              'url' => local_release_path,
            }]
        })
    end

    def self.simple_job(opts = {})
      job_hash = {
        'name' => opts.fetch(:name, 'foobar'),
        'templates' => opts.fetch(:templates, ['name' => 'foobar']),
        'resource_pool' => 'a',
        'instances' => opts.fetch(:instances, 3),
        'networks' => [{ 'name' => 'a' }],
        'properties' => {},
      }

      if opts.has_key?(:static_ips)
        job_hash['networks'].first['static_ips'] = opts[:static_ips]
      end

      if opts[:persistent_disk_pool]
        job_hash['persistent_disk_pool'] = opts[:persistent_disk_pool]
      end

      if opts.has_key?(:azs)
        job_hash['azs'] = opts[:azs]
      end

      if opts.has_key?(:properties)
        job_hash['properties'] = opts[:properties]
      end

      job_hash
    end

    def self.job_with_many_templates(options={})
      {
          'name'          => options.fetch(:name),
          'templates'      => options.fetch(:templates),
          'resource_pool' => 'a',
          'instances'     => options.fetch(:instances, 3),
          'networks'      => [{ 'name' => 'a' }],
          'properties'    => options.fetch(:properties, {}),
      }
    end

    def self.manifest_with_errand
      manifest = simple_manifest.merge('name' => 'errand')
      manifest['jobs'].find { |job| job['name'] == 'foobar'}['instances'] = 1
      manifest['jobs'] << simple_errand_job
      manifest
    end

    def self.simple_errand_job
      {
        'name' => 'fake-errand-name',
        'templates' => [
          {
            'release' => 'bosh-release',
            'name' => 'errand1'
          }
        ],
        'lifecycle' => 'errand',
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
        'properties' => {
          'errand1' => {
            'exit_code' => 0,
            'stdout' => 'fake-errand-stdout',
            'stderr' => 'fake-errand-stderr',
            'run_package_file' => true,
          },
        },
      }
    end
  end
end
