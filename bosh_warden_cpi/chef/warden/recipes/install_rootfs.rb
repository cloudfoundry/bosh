ROOT_FS = "/var/warden/rootfs".freeze
WARDEN_STEMCELL_FILE="last_successful_bosh-stemcell.tgz".freeze
WARDEN_STEMCELL_URL = "https://s3.amazonaws.com/bosh-jenkins-artifacts/#{WARDEN_STEMCELL_FILE}".freeze
STEMCELL_MOUNT = "/mnt/stemcell".freeze
RUBY_BUILD_DIR = "tmp/ruby-build"
PREFIX = "/usr/local"
RUBY_VERSION = "1.9.3-p392"

execute "install mounting packages" do
  command "apt-get update && apt-get --yes install wget kpartx"
end

if !File.exists?("#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}") ||
  File.zero?("#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}")
  remote_file "#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}" do
    source WARDEN_STEMCELL_URL
  end
end

ruby_block "install warden rootfs" do
  block do
    system "echo '----> Downloading BOSH Stemcell'"
    system "tar xvf #{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE} && tar xvf image"

    system "echo '----> Mounting BOSH Stemcell'"
    loop = `kpartx -av root.img`.match /map\s+(.+?)\s+/

    FileUtils.mkdir_p STEMCELL_MOUNT
    system "mount /dev/mapper/#{loop[1]} #{STEMCELL_MOUNT}"

    system "echo '----> Replacing standard Warden RootFS with BOSH Warden RootFS'"
    FileUtils.rm_rf ROOT_FS if File.exist? ROOT_FS
    FileUtils.mkdir_p ROOT_FS
    system "tar xzf #{STEMCELL_MOUNT}/var/vcap/stemcell_base.tar.gz -C #{ROOT_FS}"

    system "echo '----> Unmounting BOSH Stemcell'"
    system "umount #{STEMCELL_MOUNT}"
    system "kpartx -dv root.img"
    FileUtils.rm_rf STEMCELL_MOUNT
  end
  action :create
end

execute "copy resolv.conf from outside container" do
  command "cp /etc/resolv.conf #{ROOT_FS}/etc/resolv.conf"
end

execute_in_chroot "install packages" do
  root_dir ROOT_FS
  command "apt-get update && apt-get --yes install zlib1g-dev unzip curl git-core"
end

git "#{ROOT_FS}/#{RUBY_BUILD_DIR}" do
  repository "git://github.com/sstephenson/ruby-build.git"
  reference "master"
  action :sync
end

# TODO: this is because we bosh package dea_ruby. This should be removed when
# everything becomes warden_stemcell + buildpack, instead of warden_stemcell + bi-mounted bosh packages +
# buildpack.
execute_in_chroot "install ruby" do
  root_dir ROOT_FS
  command [
              "cd #{RUBY_BUILD_DIR}",
              "PREFIX=#{PREFIX} ./install.sh",
              "#{PREFIX}/bin/ruby-build #{RUBY_VERSION} #{PREFIX}/ruby"
          ].join(' && ')
  creates "#{ROOT_FS}/#{PREFIX}/ruby/bin/ruby"
end

