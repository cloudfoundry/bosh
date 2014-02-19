module Bosh::Cli::Client
  class CompiledPackagesClient
    def initialize(director)
      @director = director
    end

    def export(release_name, release_version, stemcell_name, stemcell_version)
      path = "/compiled_package_groups/export"
      content_type = 'application/json'

      body = JSON.dump(
        stemcell_name: stemcell_name,
        stemcell_version: stemcell_version,
        release_name: release_name,
        release_version: release_version,
      )

      _, file_path, _ = @director.post(path, content_type, body, {}, file: true)
      file_path
    end

    def import(exported_tar_path)
      path = '/compiled_package_groups/import'

      @director.upload_and_track(:post, path, exported_tar_path, {content_type: 'application/x-compressed'})
    end
  end
end
