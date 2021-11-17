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
          'stemcell_os' => Config.stemcell_os,
          'stemcell_version' => Config.stemcell_version,
          'user_authentication' => @config.identity_provider.client_info,
          'features' => {
            'local_dns' => {
              'status' => Config.local_dns_enabled?,
              'extras' => { 'domain_name' => Config.root_domain },
            },
            'power_dns' => {
              'status' => @powerdns_manager.dns_enabled?,
              'extras' => { 'domain_name' => @powerdns_manager.root_domain },
            },
            'snapshots' => {
              'status' => Config.enable_snapshots,
            },
            'config_server' => {
              'status' => Config.config_server_enabled,
              'extras' => {
                'urls' => @config.config_server_urls,
              },
            },
          },
        }

        content_type(:json)
        json_encode(status)
      end
    end
  end
end
