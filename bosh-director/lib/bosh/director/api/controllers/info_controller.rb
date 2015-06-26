require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class InfoController < BaseController
      def requires_authentication?
        false
      end

      get '/' do
        status = {
          'name' => Config.name,
          'uuid' => Config.uuid,
          'version' => "#{VERSION} (#{Config.revision})",
          'user' => current_user,
          'cpi' => Config.cloud_type,
          'user_authentication' => @config.identity_provider.client_info,
          'features' => {
            'dns' => {
              'status' => Config.dns_enabled?,
              'extras' => {'domain_name' => dns_domain_name}
            },
            'compiled_package_cache' => {
              'status' => Config.use_compiled_package_cache?,
              'extras' => {'provider' => Config.compiled_package_cache_provider}
            },
            'snapshots' => {
              'status' => Config.enable_snapshots
            }
          }
        }
        content_type(:json)
        json_encode(status)
      end
    end
  end
end
