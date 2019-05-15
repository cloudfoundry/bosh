# IP reservation flow

## IP address uniqueness

IP addresses are unique globally.

When using *cloud config* a director becomes responsible for managing IP allocations across multiple deployments. Any IP addresses reserved by one deployment will not be available to another deployment.

An instance from one deployment may later reserve an IP address released from another deployment.

## IP address lifecycle

```
  IP   persistent_disk
  ^    ^
  |    |
Instance --> VM
```

The instance is the owner of a given IP address. As long as the instance exists, its IP address will be reserved by that instance and cannot be used by other instances, from any deployment. An instance may lose its VM, but the IP address will still be reserved for the instance. When the VM for the instance is recreated, it will receive the instance's IP address.

Deleting an instance results in all of its IPs being released. This applies to compilation instances and no longer needed instances (e.g. the number of instances was decreased or a job's availability zone was removed).

## IP management

The IP provider is responsible for IP management. IP allocations are managed by [`DatabaseIpRepo`](../bosh-director/lib/bosh/director/deployment_plan/ip_provider/database_ip_repo.rb).

### DatabaseIpRepo

IP reservations are stored in database and shared between multiple deployments.

When re-reserving the same IP `DatabaseIpRepo` verifies if it belongs to the same instance. Otherwise it throws a `NetworkReservationAlreadyInUse` error.

## Deployment flow

During deploy network reservations are going through the following set of steps:

1. While constructing the deployment plan we create a set of desired network reservations for each instance. If instances
are configured for static IPs, we create static reservations; otherwise we create dynamic reservations. Only one
reservation can exist per network for a given instance. Requesting a second reservation for the same network will
throw a `NetworkReservationAlreadyExists` error.

2. For existing instances we create the set of the current network reservations from the director database.
For dynamic networks and VIP networks with static reservations, the network assigned to the reservation is the one that matches by name in the new cloud config, otherwise it is nil.
For manual networks and VIP networks with automatic reservations, the network assigned is the one that contains the saved IP in its subnet
range.
After these existing reservations are created, the IPs are reserved.

3. Next we try to bind existing network reservations to our desired network in the reservation reconciler. An
existing reservation can be reconciled with a desired reservation in the following scenarios:
  * the reservations are both dynamic reservations
  * the reservations both static reservations and reserve the same IP
  * the reservations are both VIP reservations

  We won't allow reuse if the desired AZ is not contained in the existing reservation network.
  If a reservation can be reconciled it is removed from the list of pre-existing reservations and the corresponding desired reservation is marked as reserved.

4. Next we reserve each desired network reservation which is not already reserved. Behavior depends on the network `type`:

  For `manual` and `vip` networks:

  * For static network reservations (specified in manifest with `static_ips`) we reserve the requested IP address.
  If the IP address is already reserved by any another instance we throw a `NetworkReservationAlreadyInUse` error.
  IPs are assigned in the order of the array the operator has configured.

  * For automatic (represented in code as 'dynamic') network reservation we allocate the next available IP address in the subnet's available IP space. If there are no more available IP addresses we throw a `NetworkReservationNotEnoughCapacity` error.

  For `dynamic` network:

  * Only automatic network reservations are allowed.

  * Director is not responsible for picking the IP address (delegated to IaaS).

5. For compilation VMs we create and reserve dynamic network reservations for the network that is specified in manifest for compilation (dynamic or manual).

6. After compilation is finished and the instance is deleted, the compilation instance's IP address is released.

7. For every existing instance that has updated network settings we release old network reservations.

8. For every instance that is no longer needed (e.g. number of instances on a job is reduced) we release those network reservations.


## Releasing IPs for non-existent networks/subnets

When an existing instance has an IP address reservation on a network that no longer exists, we assign the existing reservation a placeholder network (represented in code as a generic `Network`). The IP does not get reserved.
By attaching the IP to a reservation with a dummy network, we make sure it follows the standard reservation release code path when the reservation is marked as obsolete via the `DatabaseIpRepo`.
This ensures the IP is removed safely, as opposed to an one-off deletion from the database.

## Releasing IPs for non-existent instances

As part of the deployment flow we delete obsolete instances. Every instance entry in the database for that deployment that is not requested in deployment manifest gets deleted and all of its IP addresses are released.

## Example use cases (when using cloud config)

* When the VM is deleted from the IaaS (e.g. someone logs into aws console and deletes a vm from the list of vms)

  On subsequent deploy the VM gets an IP that was previously reserved for the instance.

* VM is detached (running `bosh stop --hard`)

  When the owning instance's VM is brought back up, it get an IP that was previously reserved for the instance.

* Recreating VM during cloud check

  VM is being re-created with IP that was previously reserved for the instance. While VM is deleted other instances cannot reserve its IP address.

* When instance is deleted via scaling down number of instances for job

  Its IP addresses will be released right after instance is deleted.

* When instance IP needs to be updated because of a change in network settings (e.g. changing availability zone, assigning a different static IP, or changing the subnet range)

  New IP address gets reserved at the beginning of deploy, old IP address is released after VM is reconfigured/recreated with new IP address.

  *Note:* IP of the instance is not updated when gateway or DNS is changed.

* When deploy fails due to VM creation failure

  All instances that require new IP addresses will hold reservations for both old and new IP addresses. On subsequent `deploy`/`cck` the old IP addresses will be released.

* When a network is renamed with the same configuration

  For VIP and manual networks, all instances should retain their assigned IPs. There is no guarantee for dynamic networks since it is up to the Iaas.
