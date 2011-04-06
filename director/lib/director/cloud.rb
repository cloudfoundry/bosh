module Bosh::Director

  ##
  # CPI - Cloud Provider Interface, used for interfacing with various IaaS APIs.
  #
  # Key terms:
  # Stemcell:: template used for creating VMs (shouldn't be powered on)
  # VM::       VM created from a stemcell with custom settings (networking and resources)
  # Disk::     volume that can be attached and detached from the VMs,
  #            never attached to more than a single VM at one time
  class Cloud

    ##
    # Creates a stemcell
    #
    # @param [String] image path to an opaque blob containing the stemcell image
    # @param [Hash] cloud_properties properties required for creating this template
    #               specific to a CPI
    # @return [String] opaque id later used by {#create_vm} and {#delete_stemcell}
    def create_stemcell(image, cloud_properties)

    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    # @return nil
    def delete_stemcell(stemcell)

    end

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
    # @param [String] agent_id UUID for the agent that will be used later on by the director
    #                 to locate and talk to the agent
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    # @param [Hash] resource_pool cloud specific properties describing the resources needed
    #               for this VM
    # @param [Hash] networks list of networks and their settings needed for this VM
    # @param [optional, String] disk_locality disk id if known of the disk that will be attached
    #                           to this vm
    # @param [optional, Hash] env environment that will be passed to this vm
    # @return [String] opaque id later used by {#configure_networks}, {#attach_disk},
    #                  {#detach_disk}, and {#delete_vm}
    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil, env = nil)

    end

    ##
    # Deletes a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @return nil
    def delete_vm(vm)

    end

    ##
    # Configures networking an existing VM.
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] networks list of networks and their settings needed for this VM,
    #               same as the networks argument in {#create_vm}
    # @return nil
    def configure_networks(vm, networks)

    end

    ##
    # Creates a disk (possibly lazily) that will be attached later to a VM. When
    # VM locality is specified the disk will be placed near the VM so it won't have to move
    # when it's attached later.
    #
    # @param [Integer] size disk size in MB
    # @param [optional, String] vm_locality vm id if known of the VM that this disk will
    #                           be attached to
    # @return [String] opaque id later used by {#attach_disk}, {#detach_disk}, and {#delete_disk}
    def create_disk(size, vm_locality = nil)

    end

    ##
    # Deletes a disk
    # Will raise an exception if the disk is attached to a VM
    #
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def delete_disk(disk)

    end


    ##
    # Attaches a disk
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def attach_disk(vm, disk)

    end

    ##
    # Detaches a disk
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def detach_disk(vm, disk)

    end

    ##
    # Validates the deployment
    # @api not_yet_used
    def validate_deployment(old_manifest, new_manifest)

    end

  end
end