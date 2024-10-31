module IntegrationSupport
  module LinksHelper
    def upload_links_release(bosh_runner_options:)
      FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, IntegrationSupport::ClientSandbox.links_release_dir, preserve: true)
      bosh_runner.run_in_dir('create-release --force', IntegrationSupport::ClientSandbox.links_release_dir, bosh_runner_options)
      bosh_runner.run_in_dir('upload-release', IntegrationSupport::ClientSandbox.links_release_dir, bosh_runner_options)
    end

    def get_link_providers
      get_json('/link_providers', 'deployment=simple')
    end

    def get_link_consumers
      get_json('/link_consumers', 'deployment=simple')
    end

    def get_links
      get_json('/links', 'deployment=simple')
    end

    def get_json(path, params)
      JSON.parse send_director_get_request(path, params).read_body
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationSupport::LinksHelper)
end
