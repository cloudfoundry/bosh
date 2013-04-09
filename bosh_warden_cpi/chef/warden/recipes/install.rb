WARDEN_PATH = "/warden"
ROOT_FS = "/var/warden/rootfs"
OLD_CONFIG_FILE_PATH = "#{WARDEN_PATH}/warden/config/warden-cpi-linux.yml"
NEW_CONFIG_FILE_PATH = "#{WARDEN_PATH}/warden/config/warden-cpi-vm.yml"

package "build-essential" do
  action :install
end

execute "install bundler" do
  command "gem install bundler"
end

git WARDEN_PATH do
  repository "git://github.com/cloudfoundry/warden.git"
  revision "9712451911c7a0fad149f83895169a4062c47fc3" #"2ab01c5fed198ee451837b062f0e02e783519289"
  action :sync
end

ruby_block "configure warden to put its rootfs outside of /tmp" do
  block do
    require "yaml"
    config = YAML.load_file(OLD_CONFIG_FILE_PATH)
    config["server"]["container_rootfs_path"] = ROOT_FS
    File.open(NEW_CONFIG_FILE_PATH, 'w') { |f| YAML.dump(config, f) }
  end
  action :create
end

execute "setup_warden" do
  cwd "#{WARDEN_PATH}/warden"
  command "bundle install && bundle exec rake setup:bin[#{NEW_CONFIG_FILE_PATH}]"
  action :run
end
