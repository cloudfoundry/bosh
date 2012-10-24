# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer

  module Helpers

    DEPLOYMENTS_FILE = "bosh-deployments.yml"

    def is_tgz?(path)
      File.extname(path) == ".tgz"
    end

    def cloud_plugin(config)
      err "No cloud properties defined" if config["cloud"].nil?
      err "No cloud plugin defined" if config["cloud"]["plugin"].nil?

      config["cloud"]["plugin"]
    end

    def dig_hash(hash, *path)
      path.inject(hash) do |location, key|
        location.respond_to?(:keys) ? location[key] : nil
      end
    end

  end

end
