require 'bosh/director/compiled_package'
require 'bosh/director/compiled_package/compiled_package'

module Bosh::Director::CompiledPackage
  class CompiledPackagesExport
    def initialize(options={})
      @file = options.fetch(:file)
      @exec = options.fetch(:exec, Bosh::Exec)
    end

    def extract
      tmp_dir = Dir.mktmpdir
      
      @exec.sh("tar -C #{tmp_dir} -xf #{@file}")
      
      manifest = YAML.load_file("#{tmp_dir}/compiled_packages.MF")
      packages = []
      
      manifest['compiled_packages'].each do |p|
        packages << CompiledPackage.new(
          package_name: p['package_name'],
          package_fingerprint: p['package_fingerprint'],
          sha1: p['compiled_package_sha1'],
          stemcell_sha1: p['stemcell_sha1'],
          blobstore_id: p['blobstore_id'],
          blob_path: File.join(tmp_dir, 'compiled_packages', 'blobs', p['blobstore_id']),
        )
      end

      yield manifest, packages

      FileUtils.rm_rf(tmp_dir)
    end
  end
end
