module Bosh::Registry

  class InstanceManager

    class Openstack < InstanceManager

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @openstack_properties = cloud_config['openstack']

        unless @openstack_properties['auth_url'].match(/\/tokens$/)
          if is_v3? @openstack_properties['auth_url']
            @openstack_properties['auth_url'] = @openstack_properties['auth_url'] + '/auth/tokens'
          else
            @openstack_properties['auth_url'] = @openstack_properties['auth_url'] + '/tokens'
          end
        end

        @openstack_options = {
          :provider => 'OpenStack',
          :openstack_auth_url => @openstack_properties['auth_url'],
          :openstack_username => @openstack_properties['username'],
          :openstack_api_key => @openstack_properties['api_key'],
          :openstack_tenant => @openstack_properties['tenant'],
          :openstack_project_name => @openstack_properties['project'],
          :openstack_domain_name => @openstack_properties['domain'],
          :openstack_user_domain_name => @openstack_properties['user_domain_name'],
          :openstack_project_domain_name => @openstack_properties['project_domain_name'],
          :openstack_region => @openstack_properties['region'],
          :openstack_endpoint_type => @openstack_properties['endpoint_type'],
          :connection_options => @openstack_properties['connection_options']
        }
      end

      def openstack
        @openstack ||= Fog::Compute.new(@openstack_options)
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?('openstack') &&
               cloud_config['openstack'].is_a?(Hash) &&
               cloud_config['openstack']['auth_url'] &&
               cloud_config['openstack']['username'] &&
               cloud_config['openstack']['api_key']
          raise ConfigError, 'Invalid OpenStack configuration parameters'
        end

        if cloud_config['openstack']['auth_url'].match(/v2(\.\d+)?/)
          unless cloud_config['openstack']['tenant']
            raise ConfigError, 'Invalid OpenStack configuration parameters'
          end

        elsif is_v3? cloud_config['openstack']['auth_url']
          unless (cloud_config['openstack']['domain'] && cloud_config['openstack']['project']) || (cloud_config['openstack']['user_domain_name'] && cloud_config['openstack']['project_domain_name'] && cloud_config['openstack']['project'])
            raise ConfigError, 'Invalid OpenStack configuration parameters'
          end
        end
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the OpenStack auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance = openstack.servers.find { |s| s.name == instance_id }
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @openstack = nil
            retry
          end
          raise ConnectionError, "Unable to connect to OpenStack API: #{e.message}"
        end
        raise InstanceNotFound, "Instance '#{instance_id}' not found" unless instance
        return instance.ip_addresses
      end

      private
      def is_v3?(url)
        url.match(/\/v3(?=\/|$)/)
      end
    end

  end

end
