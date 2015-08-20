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

          'resource_pools' => [resource_pool]
        })
    end

    def self.resource_pool
      {
        'name' => 'a',
        'size' => 3,
        'cloud_properties' => {},
        'network' => 'a',
        'stemcell' => {
          'name' => 'ubuntu-stemcell',
          'version' => '1',
        },
      }
    end

    def self.disk_pool
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

    def self.manifest_with_jobs
      {
          'name' => 'minimal',
          'director_uuid'  => 'deadbeef',

          'releases' => [{
                             'name'    => 'appcloud',
                             'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
                         }],

          'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
          },

          'jobs' => [{
                         'name'          => 'cacher',
                         'templates'      => [{
                                                  'name'    => 'cacher',
                                                  'release' => 'appcloud'
                                              }],
                         'resource_pool' => 'a',
                         'instances'     => 3,
                         'networks'      => [{ 'name' => 'a' }],
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

    def self.simple_job(options={})
      {
        'name'          => options.fetch(:name, 'foobar'),
        'template'      => 'foobar',
        'resource_pool' => 'a',
        'instances'     => options.fetch(:instances, 3),
        'networks'      => [{ 'name' => 'a' }],
      }
    end

    def self.job_with_many_templates(options={})
      {
          'name'          => options.fetch(:name),
          'templates'      => options.fetch(:templates),
          'resource_pool' => 'a',
          'instances'     => options.fetch(:instances, 3),
          'networks'      => [{ 'name' => 'a' }],
      }
    end

    def self.manifest_with_errand
      manifest = simple_manifest.merge('name' => 'errand')
      manifest['jobs'].find { |job| job['name'] == 'foobar'}['instances'] = 1

      manifest['jobs'] << {
        'name' => 'fake-errand-name',
        'template' => 'errand1',
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

      manifest
    end
  end
end
