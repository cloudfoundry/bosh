#####bosh_runner.run('deployments')
```
Name    Release(s)            Stemcell(s)        Team(s)  Cloud Config  
simple  bosh-release/0+dev.1  ubuntu-stemcell/1  -        latest        

1 deployments
```

#####[Postgres] bosh_runner.run('instances --details')
```
Deployment 'simple'

Instance                                          Process State  AZ  IPs        State     VM CID  VM Type  Disk CIDs                         Agent ID  Index  Resurrection  Bootstrap  Ignore  
                                                                                                                                                              Paused                           
ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa  -              z1  10.10.0.2  detached  -       small    b89bca7442e0c2b15e80d558200f9cb8  -         0      false         true       false      

1 instances
```

#####[Mysql] bosh_runner.run('instances --details')
```
Deployment 'simple'

Instance                                          Process State  AZ  IPs        State     VM CID  VM Type  Disk CIDs                         Agent ID  Index  Resurrection  Bootstrap  Ignore  
                                                                                                                                                              Paused                           
ig_provider/1e54789f-551b-4f3d-bf43-84ce6647ec5c  -              z1  10.10.0.2  detached  -       small    c0547d4abc0619b45fe1c3979a0ae8bf  -         0      false         true       false   

1 instances
```

#####Deployment manifest
```
{
  'name' => 'simple',
  'director_uuid' => 'deadbeef',
  'releases' => [{'name' => 'bosh-release', 'version' => 'latest'}],
  'update' => {
    'canaries' => 2,
    'canary_watch_time' => 4000,
    'max_in_flight' => 1,
    'update_watch_time' => 20
  },
  'instance_groups' => [{
    'name' => 'ig_provider',
    'jobs' => [{
      'name' => 'provider',
      'provides' => {
        'provider' => { 'as' => 'provider_link', 'shared' => true}
      },
      'properties' => {
        'a' => '1',
        'b' => '2',
        'c' => '3',
      }
    }],
    'instances' => 2,
    'networks' => [{'name' => 'private'}],
    'vm_type' => 'small',
    'persistent_disk_type' => 'small',
    'azs' => ['z1'],
    'stemcell' => 'default'
  }],
  'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
}
```

#####Cloud Config
```
{
  'azs' => [{'name' => 'z1'}],
  'vm_types' => [{'name' => 'small'}],
  'disk_types' => [{
    'name' => 'small',
    'disk_size' => 3000
  }],
  'networks' => [{
    'name' => 'private',
    'type' => 'manual',
    'subnets' => [
      {
        'range' => '10.10.0.0/24',
        'gateway' => '10.10.0.1',
        'az' => 'z1',
        'static' => ['10.10.0.62'],
        'dns' => ['10.10.0.2'],
      }
    ]
  }],
  'compilation' => {
    'workers' => 5,
    'reuse_compilation_vms' => true,
    'az' => 'z1',
    'vm_type' => 'small',
    'network' => 'private'
  }
}
```  