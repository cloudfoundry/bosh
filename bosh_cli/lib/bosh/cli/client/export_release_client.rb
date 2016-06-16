module Bosh::Cli::Client
  class ExportReleaseClient
    def initialize(director)
      @director = director
    end

    def export(deployment_name, release_name, release_version, stemcell_os, stemcell_version)
      path = "/releases/export"
      content_type = 'application/json'

      body = JSON.dump(
          deployment_name: deployment_name,
          release_name: release_name,
          release_version: release_version,
          stemcell_os: stemcell_os,
          stemcell_version: stemcell_version,
      )

      @director.request_and_track(:post, path, {content_type: content_type, payload: body })
    end
  end
end