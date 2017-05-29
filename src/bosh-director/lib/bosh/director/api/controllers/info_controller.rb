require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class InfoController < BaseController

      def initialize(config)
        super(config)
        @powerdns_manager = PowerDnsManagerProvider.create
      end

      def requires_authentication?
        false
      end

      get '/' do
        status = {
          'name' => Config.name,
          'uuid' => Config.uuid,
          'version' => "#{Config.version} (#{Config.revision})",
          'user' => current_user,
          'cpi' => Config.cloud_type,
          'user_authentication' => @config.identity_provider.client_info,
          'features' => {
            'dns' => {
              'status' => @powerdns_manager.dns_enabled?,
              'extras' => {'domain_name' => @powerdns_manager.root_domain}
            },
            'compiled_package_cache' => {
              'status' => Config.use_compiled_package_cache?,
              'extras' => {'provider' => Config.compiled_package_cache_provider}
            },
            'snapshots' => {
              'status' => Config.enable_snapshots
            },
            'config_server' => {
              'status' => Config.config_server_enabled,
              'extras' => {
                'urls' => @config.config_server_urls
              }
            }
          }
        }

        content_type(:json)
        json_encode(status)
      end
    end
  end
end
