# Copyright (c) 2009-2018 VMware, Inc.

module Bosh; module Clouds; end; end

require "forwardable"

require "cloud/config"
require "cloud/errors"
require "cloud_v1"

module Bosh

  ##
  # CPI - Cloud Provider Interface, used for interfacing with various IaaS APIs.
  #
  # Key terms:
  # Stemcell: template used for creating VMs (shouldn't be powered on)
  # VM:       VM created from a stemcell with custom settings (networking and resources)
  # Disk:     volume that can be attached and detached from the VMs,
  #           never attached to more than a single VM at one time
  module CloudV2
    include Bosh::CloudV1
    ##
    # Creates a VM - creates (and powers on) a VM from a stemcell with the proper resources
    # and on the specified network. When disk locality is present the VM will be placed near
    # the provided disk so it won't have to move when the disk is attached later.
    #
    # Sample networking config:
    #  {"network_a" =>
    #    {
    #      "netmask"          => "255.255.248.0",
    #      "ip"               => "172.30.41.40",
    #      "gateway"          => "172.30.40.1",
    #      "dns"              => ["172.30.22.153", "172.30.22.154"],
    #      "cloud_properties" => {"name" => "VLAN444"}
    #    }
    #  }
    #
    # Sample resource pool config (CPI specific):
    #  {
    #    "ram"  => 512,
    #    "disk" => 512,
    #    "cpu"  => 1
    #  }
    # or similar for EC2:
    #  {"name" => "m1.small"}
    #
    # Sample return value:
    # [
    #   "vm-cid-123",
    #   { # ... networks ...
    #     "private": {
    #       "type": "manual",
    #       "netmask": "255.255.255.0",
    #       "gateway": "10.230.13.1",
    #       "ip": "10.230.13.6",
    #       "default": [ "dns", "gateway" ],
    #       "cloud_properties": {
    #         "net_id": "d29fdb0d-44d8-4e04-818d-5b03888f8eaa"
    #       }
    #      },
    #     "public": {
    #       "type": "vip",
    #       "ip": "173.101.112.104",
    #       "cloud_properties": {}
    #     }
    #   }
    # ]
    #
    # @param [String] agent_id UUID for the agent that will be used later on by the director
    #                 to locate and talk to the agent
    # @param [String] stemcell_id stemcell id that was once returned by {#create_stemcell}
    # @param [Hash] resource_pool cloud specific properties describing the resources needed
    #               for this VM
    # @param [Hash] networks list of networks and their settings needed for this VM
    # @param [String, Array] disk_locality disk id(s) if known of the disk(s) that will be
    #                                    attached to this vm
    # @param [Hash] env environment that will be passed to this vm
    # @return [Array] [VM_ID, {...networks...}]
    def create_vm(agent_id, stemcell_id, resource_pool, networks, disk_locality, env)
      not_implemented(:create_vm)
    end

    # Attaches a disk
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return [String] hint for location of attached disk
    #
    # Sample return value for attach_disk
    # "/dev/sdd"
    #
    def attach_disk(vm_id, disk_id)
      not_implemented(:attach_disk)
    end

    private

    def not_implemented(method)
      raise Bosh::Clouds::NotImplemented, "'#{method}' is not implemented by #{self.class}"
    end
  end
end
