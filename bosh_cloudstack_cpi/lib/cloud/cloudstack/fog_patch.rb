module Fog
  module Compute
    class Cloudstack
      request :create_tags
      request :delete_tags
      request :list_tags
      request :create_template
      request :disassociate_ip_address
      request :create_vlan_ip_range
      request :delete_vlan_ip_range
      request :list_vlan_ip_ranges
      request :enable_static_nat
      request :disable_static_nat

      model :nat
      collection :nats
      model :vlan
      collection :vlans
      model :ipaddress
      collection :ipaddresses
      model :network
      collection :networks
      model :disk_offering
      collection :disk_offerings
      model :key_pair
      collection :key_pairs
      model :ostype
      collection :ostypes
      model :firewall
      collection :firewalls
    end
  end
end
