# Example apply spec for bosh-sample-release (wordpress)

After deploying the [single-VM example](https://github.com/cloudfoundry/bosh-sample-release/blob/master/examples/wordpress-openstack-vip-micro.yml), ssh into the `core/0` vm and get the spec used to setup the VM.

```
$ git clone https://github.com/cloudfoundry/bosh-sample-release.git
$ cd bosh-sample-release
$ bosh upload release releases/wordpress-2.yml
# change director UUID, IP address, cloud_properties in examples/wordpress-openstack-vip-micro.yml
$ bosh deploy
$ bosh ssh core/0
$ sudo grep apply /var/vcap/bosh/log/current
...
2013-05-30_23:54:40.48236 #[977] INFO: Message: {"method"=>"apply", "arguments"=>[{"deployment"=>"wordpress",
 "release"=>{"name"=>"wordpress", "version"=>"2"}, "job"=>{"name"=>"core", "release"=>"wordpress", 
 "templates"=>[{"name"=>"mysql", "version"=>"2", "sha1"=>"5484694f00c2a700ec7980485385a32dbcd32d5e", 
 "blobstore_id"=>"b0ef62b7-639a-42d6-93bb-e6dc7dfe1bea"}, {"name"=>"debian_nfs_server", "version"=>"2", 
 "sha1"=>"86bad1b919b9eadec0b269e825f94a371a5f429f", "blobstore_id"=>"6f853372-c202-46e3-9aad-a18bf645d1f6"}, {"name"=>"wordpress", 
 "version"=>"2", "sha1"=>"724eafc30d1b6cc8d16848a214d7a479ecce753c", "blobstore_id"=>"5f5af1d9-e41c-4937-ad58-a6859e63f2c5"}, 
 {"name"=>"nginx", "version"=>"2", "sha1"=>"7ecc6cac90c344c371699abecb8ad17e692b2cb4", 
 "blobstore_id"=>"2e991766-6dc5-4fa3-a522-8672f2f8ae9b"}], "template"=>"mysql", "version"=>"2", 
 "sha1"=>"5484694f00c2a700ec7980485385a32dbcd32d5e", "blobstore_id"=>"b0ef62b7-639a-42d6-93bb-e6dc7dfe1bea"}, "index"=>0, 
 "networks"=>{"default"=>{"type"=>"dynamic", "cloud_properties"=>{"security_groups"=>["default"]}, "dns"=>["10.0.0.2", "10.0.0.1"], 
 "default"=>["dns", "gateway"], "ip"=>"10.0.0.3", "netmask"=>"255.255.255.0", "gateway"=>"10.0.0.1"}, "floating"=>{"type"=>"vip", 
 "ip"=>"216.55.141.199", "cloud_properties"=>{}}}, "resource_pool"=>{"name"=>"common", 
 "cloud_properties"=>{"instance_type"=>"m1.microbosh"}, "stemcell"=>{"name"=>"bosh-stemcell", "version"=>"679"}}, 
 "packages"=>{"wordpress"=>{"name"=>"wordpress", "version"=>"1.1", "sha1"=>"00d8f996baeb08540f614f294b04c5529b59644d", 
 "blobstore_id"=>"69965b4d-3931-43a4-98f3-1246f45e2156"}, "debian_nfs_server"=>{"name"=>"debian_nfs_server", "version"=>"1.1", 
 "sha1"=>"234d05f0a7c3f942000a468bdd814d467921ccfd", "blobstore_id"=>"d4b40f39-35cd-4313-a2ae-2f2605b3d991"}, 
 "common"=>{"name"=>"common", "version"=>"1.1", "sha1"=>"7d5d15b07ba5a8736973dd108c2b88cb496a6001", 
 "blobstore_id"=>"9ce1644b-8383-4152-9e08-de1b01c5cf10"}, "mysql"=>{"name"=>"mysql", "version"=>"1.1", 
 "sha1"=>"3faf4bae19e81068026890a489007d07ebf385f5", "blobstore_id"=>"5dc2cde8-45ee-4670-9799-f587a1a42164"}, 
 "mysqlclient"=>{"name"=>"mysqlclient", "version"=>"1.1", "sha1"=>"357eaab6ce2f069e3714a7f366e6f31fd216f04a", 
 "blobstore_id"=>"30174e00-8920-4474-8241-6a56f8da10e6"}, "nginx"=>{"name"=>"nginx", "version"=>"1.1", 
 "sha1"=>"91022f9f4882f2d3beba571e36932e504fa7131e", "blobstore_id"=>"bd49e4bb-4ade-4763-80b8-ec7bd62d853d"}, 
 "apache2"=>{"name"=>"apache2", "version"=>"1.1", "sha1"=>"34ce7fc243c8bf20de31f5bcc55faa7a482b5710", 
 "blobstore_id"=>"3332fe2c-2da4-4b17-a9ec-eeb25a087ce8"}, "php5"=>{"name"=>"php5", "version"=>"1.1", 
 "sha1"=>"97dcf4fff39e2761264cf670759cdcd44693f288", "blobstore_id"=>"1c403cfa-e4d4-411c-ab5d-589feb31c2d8"}}, "persistent_disk"=>0, 
 "configuration_hash"=>"4d57061218a14f64f1d05511d0c5c36751cbc979", "properties"=>{"mysql"=>{"password"=>"rootpass", "port"=>3306, 
 "production"=>false, "address"=>"216.55.141.199"}, "wordpress"=>{"db"=>{"name"=>"wp", "user"=>"wordpress", "pass"=>"w0rdpr3ss"}, 
 "port"=>8008, "admin"=>"foo@bar.com", "servername"=>"216.55.141.199", "auth_key"=>"random key", "secure_auth_key"=>"random key", 
 "logged_in_key"=>"random key", "nonce_key"=>"random key", "auth_salt"=>"random key", "secure_auth_salt"=>"random key", 
 "logged_in_salt"=>"random key", "nonce_salt"=>"random key", "servers"=>["216.55.141.199"]}, 
 "debian_nfs_server"=>{"no_root_squash"=>true}, "nfs_server"=>{"network"=>"*.wordpress.microbosh", "idmapd_domain"=>"novalocal", 
 "address"=>"216.55.141.199", "share"=>"/"}, "nginx"=>{"workers"=>1}}, 
 "template_hashes"=>{"debian_nfs_server"=>"bfe6b149163094ecfa24294a2e397d5144ec6ac3", 
 "mysql"=>"a41256997a3c4e8a48b581e6f47385f1b124b926", "nginx"=>"cf24d6f0a5c7ab2b1037f93e891c14da664541d7", 
 "wordpress"=>"4884ec2fd2e2464c7cd7bf2f42d7c1b8f24584e1"}}], 
 "reply_to"=>"director.f9ec4415-9416-4f76-93ba-a58220d62e19.c87679bf-ecdd-45b0-99a3-19dd6e734d4a"}
```