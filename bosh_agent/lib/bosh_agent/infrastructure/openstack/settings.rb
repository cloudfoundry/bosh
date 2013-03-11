# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Openstack::Settings < Infrastructure::Settings

    AUTHORIZED_KEYS = File.join("/home/", BOSH_APP_USER, ".ssh/authorized_keys")

    def load_settings
      setup_openssh_key
      Infrastructure::Openstack::Registry.get_settings
    end

    def authorized_keys
      AUTHORIZED_KEYS
    end

    def setup_openssh_key
      public_key = Infrastructure::Openstack::Registry.get_openssh_key
      if public_key.nil? || public_key.empty?
        return
      end
      FileUtils.mkdir_p(File.dirname(authorized_keys))
      FileUtils.chmod(0700, File.dirname(authorized_keys))
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, File.dirname(authorized_keys))
      File.open(authorized_keys, "w") { |f| f.write(public_key) }
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, authorized_keys)
      FileUtils.chmod(0644, authorized_keys)
    end

  end
end
