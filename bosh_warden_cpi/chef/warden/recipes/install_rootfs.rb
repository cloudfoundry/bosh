ROOT_FS = "/tmp/warden/rootfs".freeze
WARDEN_STEMCELL_FILE="last_successful_bosh-stemcell.tgz".freeze
WARDEN_STEMCELL_URL = "https://s3.amazonaws.com/bosh-jenkins-artifacts/#{WARDEN_STEMCELL_FILE}".freeze
STEMCELL_MOUNT = "/mnt/stemcell".freeze
RUBY_BUILD_DIR = "tmp/ruby-build"
PREFIX = "/usr/local"
RUBY_VERSION = "1.9.3-p392"


ROOTFS_PKG_NAME = "rootfs/lucid64.tar.gz"
CF_RELEASE_DIR = "/tmp/cf-release"

execute "install mounting packages" do
  command "apt-get update && apt-get --yes install wget kpartx"
end

#if !File.exists?("#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}") ||
#  File.zero?("#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}")
#  remote_file "#{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE}" do
#    source WARDEN_STEMCELL_URL
#  end
#end

#git "#{CF_RELEASE_DIR}" do
#  repository "git://github.com/cloudfoundry/cf-release.git"
#  reference "master"
#  action :sync
#end

if false
  execute "build warden stemcell" do
    command <<-BASH
work_dir=$(mktemp -d stemcell)
specification_file=../stemcell_builder/spec/stemcell-warden.spec
settings_file=../stemcell_builder/etc/settings.bash
../stemcell_builder/bin/build_from_spec.sh $work_dir $specification_file $settings_file"
  BASH
  end
end

if !File.exists?(CF_RELEASE_DIR)
  execute "clone cf-release" do
    command "git clone git://github.com/cloudfoundry/cf-release.git #{CF_RELEASE_DIR} --depth 1"
  end
end


rootfs_url = "http://"
ruby_block "fetch rootfs url" do
  block do
#    system "echo '----> Downloading BOSH Stemcell'"
#    system "tar xvf #{Chef::Config[:file_cache_path]}/#{WARDEN_STEMCELL_FILE} && tar xvf image"
#
#    system "echo '----> Mounting BOSH Stemcell'"
#    loop = `kpartx -av root.img`.match /map\s+(.+?)\s+/
#
#    FileUtils.mkdir_p STEMCELL_MOUNT
#    system "mount /dev/mapper/#{loop[1]} #{STEMCELL_MOUNT}"
#
#    system "echo '----> Replacing standard Warden RootFS with BOSH Warden RootFS'"
#    FileUtils.rm_rf ROOT_FS if File.exist? ROOT_FS
#    FileUtils.mkdir_p ROOT_FS

    # Get the blobstore url from final.yml
    Dir.chdir("#{CF_RELEASE_DIR}/config") do
      final = YAML.load_file("final.yml")
      blobstore_url = final["blobstore"]["options"]["bucket_name"]
      rootfs_url << blobstore_url

      blobs = YAML.load_file("blobs.yml")
      blob_path = blobs[ROOTFS_PKG_NAME]["object_id"]
      rootfs_url << "/" << blob_path
    end

#    system "tar xzf #{STEMCELL_MOUNT}/var/vcap/stemcell_base.tar.gz -C #{ROOT_FS}"
#
#    system "echo '----> Unmounting BOSH Stemcell'"
#    system "umount #{STEMCELL_MOUNT}"
#    system "kpartx -dv root.img"
#    FileUtils.rm_rf STEMCELL_MOUNT

 end
end

execute "setup vagrant file cache" do
  command "mkdir -p #{Chef::Config[:file_cache_path]}"
end

rootfs_pkg_path = "#{Chef::Config[:file_cache_path]}/#{ROOTFS_PKG_NAME}"
if !File.exists?(rootfs_pkg_path) || File.zero?(rootfs_pkg_path)
  execute "setup rootfs directory" do
    command "mkdir -p #{Chef::Config[:file_cache_path]}"
  end

  remote_file rootfs_pkg_path do
    source rootfs_url
  end
end

execute "Untar the warden rootfs" do
  command "mkdir -pv #{ROOT_FS} && tar xzf #{rootfs_pkg_path} -C #{ROOT_FS}"
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

