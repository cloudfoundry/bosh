require 'yaml'
require 'bosh/director'

module Bosh::Director
  class CompiledReleaseManifest
    def initialize(compiled_package_group, templates, stemcell)
      @compiled_packages = compiled_package_group
      @templates = templates
      @stemcell = stemcell
    end

    def generate_manifest
      manifest = {}

      manifest['compiled_packages'] = @compiled_packages.compiled_packages.map do |compiled_package|
        {
          'name' => compiled_package.package.name,
          'version' => compiled_package.package.version,
          'fingerprint' => compiled_package.package.fingerprint,
          'sha1' => compiled_package.sha1,
          'stemcell' => "#{@stemcell.operating_system}/#{@stemcell.version}",
          'dependencies' => get_dependencies(compiled_package),
        }
      end

      manifest['jobs'] = @templates.map do |template|
        {
          'name' => template.name,
          'version' => template.version,
          'fingerprint' => template.fingerprint,
          'sha1' => template.sha1,
        }
      end

      manifest['commit_hash'] = @compiled_packages.release_version.commit_hash
      manifest['uncommitted_changes'] = @compiled_packages.release_version.uncommitted_changes
      manifest['name'] = @compiled_packages.release_version.release.name
      manifest['version'] = @compiled_packages.release_version.version

      manifest
    end

    def get_dependencies(compiled_package)
      dependencies = []
      parser = Yajl::Parser.new
      hash = parser.parse(compiled_package.package.dependency_set_json)
      hash.each do |name|
        dependencies << name
      end
      dependencies
    end

    def write(dest_path)
      manifest = generate_manifest
      manifest_yaml = YAML.dump(manifest)
      logger.debug("release.MF contents of #{manifest['name']}/#{manifest['version']} compiled release tarball:\n " + manifest_yaml)
      File.open(dest_path, 'w') { |f| f.write(manifest_yaml) }
    end

    def logger
      @logger ||= Config.logger
    end

  end
end
