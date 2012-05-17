module Bosh::Spec
  class Deployments

    def self.minimal_manifest
      # This is a minimal manifest I was actually being able to deploy with. It doesn't even have any jobs,
      # so it's not very realistic though
      {
        "name" => "minimal",
        "release" => {
          "name"    => "appcloud",
          "version" => "0.1" # It's our dummy valid release from spec/assets/valid_release.tgz
        },

        "director_uuid" => "deadbeef",
        "networks"       => [ { "name" => "a", "subnets" => [  ] }, ],
        "compilation"    => { "workers" => 1, "network" => "a", "cloud_properties" => { } },
        "resource_pools" => [ ],

        "update" => {
          "canaries"          => 2,
          "canary_watch_time" => 4000,
          "max_in_flight"     => 1,
          "update_watch_time" => 20
        }
      }
    end

    def self.simple_manifest
      extras = {
        "name" => "simple",
        "release" => {
          "name"    => "bosh-release",
          "version" => "0.1-dev"
        },

        "networks" => [{ "name" => "a",
                         "subnets" => [{ "range"    => "192.168.1.0/24",
                                         "gateway"  => "192.168.1.1",
                                         "dns"      => [ "192.168.1.1", "192.168.1.2" ],
                                         "static"   => [ "192.168.1.10" ],
                                         "reserved" => [ ],
                                         "cloud_properties" => { }
                                       }]
                       }],

        "resource_pools" => [{ "name" => "a",
                               "size" => 10,
                               "cloud_properties" => { },
                               "network" => "a",
                               "stemcell" => {
                                 "name"    => "ubuntu-stemcell",
                                 "version" => "1"
                               }
                             }],

        "jobs" => [{ "name"          => "foobar",
                     "template"      => "foobar",
                     "resource_pool" => "a",
                     "instances"     => 3,
                     "networks"      => [ { "name" => "a" } ]
                   }]
      }

      minimal_manifest.merge(extras)
    end

  end
end
