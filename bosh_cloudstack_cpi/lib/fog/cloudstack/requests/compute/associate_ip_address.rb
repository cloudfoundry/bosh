module Fog
  module Compute
    class Cloudstack
      class Real

        # Aassociate an ip address.
        #
        # {CloudStack API Reference}[http://download.cloud.com/releases/2.2.0/api_2.2.4/global_admin/associateIpAddress.html]
        def associate_ip_address(options={})
          options.merge!(
              'command' => 'associateIpAddress'
          )

          request(options)
        end

      end
    end
  end
end
