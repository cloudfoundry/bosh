# stemcell image creation
package 'debootstrap'
package 'kpartx'

# stemcell uploading
package 's3cmd'

# native gem compilation
package 'g++'
package 'git-core'
package 'make'

# native gem dependencies
package 'libmysqlclient-dev'
package 'libpq-dev'
package 'libsqlite3-dev'
package 'libxml2-dev'
package 'libxslt-dev'

# vSphere requirements
package 'open-vm-dkms'

# OpenStack requirement
package 'qemu-utils'

# CentOS building requirements
package 'yum'

# caching proxy to speed up package installation in chroot
package 'apt-cacher-ng'
cookbook_file '/etc/apt-cacher-ng/centos_mirrors' do
  action :create
  source 'centos_mirrors'
end

cookbook_file '/etc/apt-cacher-ng/acng-centos.conf' do
  action :create
  source 'acng-centos.conf'
end

cookbook_file '/etc/apt-cacher-ng/backends_centos' do
  action :create
  source 'backends_centos'
end

service 'apt-cacher-ng' do
  action :restart
end
