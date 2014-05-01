module Bosh::Spec
  class Deployments
    # This is a minimal manifest that deploys successfully.
    # It doesn't have any jobs, so it's not very realistic though
    def self.minimal_manifest
      {
        'name' => 'minimal',
        'director_uuid'  => 'deadbeef',

        'releases' => [{
          'name'    => 'appcloud',
          'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
        }],

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

        'update' => {
          'canaries'          => 2,
          'canary_watch_time' => 4000,
          'max_in_flight'     => 1,
          'update_watch_time' => 20
        }
      }
    end

    def self.simple_manifest
      minimal_manifest.merge(
        'name' => 'simple',

        'releases' => [{
          'name'    => 'bosh-release',
          'version' => '0.1-dev'
        }],

        'networks' => [{
          'name'    => 'a',
          'subnets' => [{
            'range'    => '192.168.1.0/24',
            'gateway'  => '192.168.1.1',
            'dns'      => ['192.168.1.1', '192.168.1.2'],
            'static'   => ['192.168.1.10'],
            'reserved' => [],
            'cloud_properties' => {},
          }]
        }],

        'resource_pools' => [{
          'name' => 'a',
          'size' => 3,
          'cloud_properties' => {},
          'network'   => 'a',
          'stemcell'  => {
            'name'    => 'ubuntu-stemcell',
            'version' => '1'
          }
        }],

        'jobs' => [{
          'name'          => 'foobar',
          'template'      => 'foobar',
          'resource_pool' => 'a',
          'instances'     => 3,
          'networks'      => [{ 'name' => 'a' }]
        }]
      )
    end

    def self.manifest_with_errand
      manifest = simple_manifest.merge(
        'name' => 'errand'
      )
      manifest['resource_pools'].first['size'] = 4

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
