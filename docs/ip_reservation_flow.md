# IP reservation flow

## IP address uniqueness

IP addresses are unique within a BOSH network.

When using `cloud config` a director becomes responsible for managing IP allocation across multiple deployments. An IP addresses reserved by one deployment will not be available to another deployment.

An instance from one deployment may later reserve an IP address released from another deployment.

## IP address lifecycle

```
  IP   persistent_disk
  ^    ^
  |    |
Instance --> VM
```

The instance is the owner of a given IP address. As long as the instance exists, it's IP address will be reserved by that instance and cannot be used by other instances, from any deployment. An instance may lose it's VM, but the IP address should still be reserved by the instance. When the VM for the instance is recreated, it should receive the instance's IP address.

Deleting an instance results in all its IPs being released. This applies to compilation instances and no longer needed instances (e.g. the number of instances was decreased or a job's availability zone was removed).

## IP management

The IP provider is responsible for IP management. If director is not using cloud config IP allocations are managed by InMemoryIpProvider. Once cloud config is being uploaded to director it enters `global networking` mode where IP allocations are managed by DatabaseIpProvider.

### InMemoryIpProvider

For every deployment InMemoryIpProvider constructs the state of the world for this deployment from scratch. IP space is not shared between deployments.

Current IP address allocations are determined by querying the running VMs (`get_state` agent call). Every current IP address is marked as reserved in memory before allocating new IP addresses for new instances.

Re-reserving the same IP-address within deployment will cause NetworkReservationAlreadyInUse error.

### DatabaseIpProvider

IP reservations are stored in database and shared between multiple deployments.

When re-reserving the same IP DatabaseIpProvider verifies if it belongs to the same instance. Otherwise it throws NetworkReservationAlreadyInUse error.

## Deployment flow

During deploy network reservations are going through the following set of steps:

1) As part of deployment plan construction for each instance we create a set of desired network reservations. For instance with specified static IPs we create static reservations, otherwise we create dynamic reservations. Only one reservation can exist for one network. Requesting second reservation for the same network will throw an NetworkReservationAlreadyExists error.

2) Next for existing instance we create the set of actual network reservations (unbound) and reserve them with IP provider. For InMemoryIpProvider the set is constructed from current state on VM (get_state agent call). For DatabaseIpProvider the set is constructed from database records.

3) Next we try to bind actual network reservations to desired. Reservation can be reused if it belongs to the same network and in case of static reservations if requested IP address matches actual IP address. If reservation can be reused it is removed from the list of unbound reservations and corresponding desired reservation is marked as reserved.

4) Next we reserve each desired network reservation that is not reserved yet.

For manual network:

* For static network reservation (IP address was specified in manifest) we reserve requested IP address. If IP address is already reserved by another instance we throw NetworkReservationAlreadyInUse error).

* For automatic (represented in code as 'dynamic') network reservation (IP address was not specified in manifest) we allocate next available IP address in subnet's IP space. If there are no more available IP addresses we throw NetworkReservationNotEnoughCapacity error.

For dynamic network:

* Only automatic network reservations are allowed.

* Director is not responsible for picking up IP address (delegated to IaaS DHCP server).

For vip network:

* Only static network reservations with specified IP address are allowed.

* If IP was previously reserved we throw NetworkReservationAlreadyInUse error.

5) For compilation VM instance we create and reserve dynamic network reservation on a network that is specified in manifest for compilation (dynamic or manual).

6) After compilation is finished and compilation instance is deleted IP address used for compilation is released.

7) For every existing instance that has updated network settings we release old network reservations.

8) For every instance that is no longer needed (for example, number of instances on a job is scaled down) we release all its network reservations.


## Releasing IPs for non-existent networks/subnets

When instance has IP address reservations on a network that no longer exists in deployment manifest we define a dummy network (represented in code as 'default network') to release its reservations when it will be deleted. By attaching the IP to a dummy network, we make sure it follows the standard reservation release code path via either the InMemoryIpProvider or DatabaseIpProvider. This ensures the IP is removed safely, as opposed to an one-off deletion from the database. When releasing IP address on subnet that no longer contains IP address we use dummy subnet (represented in code as 'default subnet') with range '0.0.0.0/0' that fits all IP addresses.

## Releasing IPs for non-existent instances

As part of the deployment flow we delete obsolete instances. Every instance entry in the database for that deployment that is not requested in deployment manifest gets deleted and all its IP addresses are released.

## Example use cases (when using cloud config)

* When the VM is deleted from the IaaS (e.g. someone logs into aws console and deletes a vm from the list of vms)

  On subsequent deploy the VM gets an IP that was previously reserved for the instance.

* VM is detached (running `bosh stop --hard`)

  When the owning instance's VM is brought back up, it get an IP that was previously reserved for the instance.

* Recreating VM during cloud check

  VM is being re-created with IP that was previously reserved for the instance. While VM is deleted other instance can not reserve its IP address.

* When instance is deleted via scaling down number of instances for job

  Its IP addresses will be released right after instance is deleted.

* When instance IP needs to be updated because of a change in network settings (e.g.: changing availability zone, or assigning a different static IP, or changing the subnet range)

  New IP address gets reserved at the beginning of deploy, old IP address is released after VM is reconfigured/recreated with new IP address.

  Note: IP of the instance is not updated when gateway or DNS is changed.

* When deploy fails due to VM creation failure

  All instances that require new IP addresses will hold reservations for both old and new IP addresses. On subsequent deploy/cck old IP addresses will be released.

