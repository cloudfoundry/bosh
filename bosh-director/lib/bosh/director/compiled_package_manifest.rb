require 'yaml'
require 'bosh/director'

module Bosh::Director
  class CompiledPackageManifest
    def initialize(group)
      @compiled_package_group = group
    end

    def to_h
      {
        'compiled_packages' => @compiled_package_group.compiled_packages.map do |compiled_package|
          {
            'package_name' => compiled_package.package.name,
            'package_fingerprint' => compiled_package.package.fingerprint,
            'stemcell_sha1' => @compiled_package_group.stemcell_sha1,
            'blobstore_id' => compiled_package.blobstore_id,
          }
        end
      }
    end

    def write(dest_path)
      File.open(dest_path, 'w') { |f| f.write(YAML.dump(to_h)) }
    end
  end
end
