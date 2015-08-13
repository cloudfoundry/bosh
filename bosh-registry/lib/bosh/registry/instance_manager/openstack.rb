# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Registry

  class InstanceManager

    class Openstack < InstanceManager

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @openstack_properties = cloud_config['openstack']

        unless @openstack_properties['auth_url'].match(/\/tokens$/)
          @openstack_properties['auth_url'] = @openstack_properties['auth_url'] + '/tokens'
        end

        @openstack_options = {
          :provider => 'OpenStack',
          :openstack_auth_url => @openstack_properties['auth_url'],
          :openstack_username => @openstack_properties['username'],
          :openstack_api_key => @openstack_properties['api_key'],
          :openstack_tenant => @openstack_properties['tenant'],
          :openstack_domain_name => @openstack_properties['domain'],
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
            cloud_config['openstack']['api_key'] &&
            cloud_config['openstack']['tenant']
          raise ConfigError, 'Invalid OpenStack configuration parameters'
        end
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the OpenStack auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance  = openstack.servers.find { |s| s.name == instance_id }
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @openstack = nil
            retry
          end
          raise ConnectionError, "Unable to connect to OpenStack API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found" unless instance
        return (instance.private_ip_addresses + instance.floating_ip_addresses).compact
      end

    end

  end

end
