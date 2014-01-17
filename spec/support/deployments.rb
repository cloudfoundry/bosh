module Bosh::Spec
  class Deployments
    # This is a minimal manifest that deploys successfully.
    # It doesn't have any jobs, so it's not very realistic though
    def self.minimal_manifest
      {
        "name" => "minimal",
        "director_uuid"  => "deadbeef",

        "releases" => [{
          "name"    => "appcloud",
          "version" => "0.1" # It's our dummy valid release from spec/assets/valid_release.tgz
        }],

        "networks" => [{
          "name" => "a",
          "subnets" => [],
        }],

        "compilation" => {
          "workers" => 1,
          "network" => "a",
          "cloud_properties" => {},
        },

        "resource_pools" => [],

        "update" => {
          "canaries"          => 2,
          "canary_watch_time" => 4000,
          "max_in_flight"     => 1,
          "update_watch_time" => 20
        }
      }
    end

    def self.simple_manifest
      minimal_manifest.merge(
        "name" => "simple",

        "releases" => [{
          "name"    => "bosh-release",
          "version" => "0.1-dev"
        }],

        "networks" => [{
          "name"    => "a",
          "subnets" => [{
            "range"    => "192.168.1.0/24",
            "gateway"  => "192.168.1.1",
            "dns"      => ["192.168.1.1", "192.168.1.2"],
            "static"   => ["192.168.1.10"],
            "reserved" => [],
            "cloud_properties" => {},
          }]
        }],

        "resource_pools" => [{
          "name" => "a",
          "size" => 3,
          "cloud_properties" => {},
          "network"   => "a",
          "stemcell"  => {
            "name"    => "ubuntu-stemcell",
            "version" => "1"
          }
        }],

        "jobs" => [{
          "name"          => "foobar",
          "template"      => "foobar",
          "resource_pool" => "a",
          "instances"     => 3,
          "networks"      => [{ "name" => "a" }]
        }]
      )
    end
  end
end
