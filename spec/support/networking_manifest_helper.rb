module Bosh::Spec
  class NetworkingManifest
    def self.deployment_manifest(opts)
      manifest = Bosh::Spec::Deployments.simple_manifest
      manifest['name'] = opts.fetch(:name, 'simple')
      manifest['jobs'].first['instances'] = opts.fetch(:instances, 1)
      manifest
    end

    def self.cloud_config(opts)
      ip_range = NetAddr::CIDR.create('192.168.1.0/24')
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      ip_range_shift = opts.fetch(:shift_ip_range_by, 0)
      ip_to_reserve_from = ip_range.nth(opts.fetch(:available_ips)+2+ip_range_shift) # first IP is gateway, range is inclusive, so +2

      reserved_ips = ["#{ip_to_reserve_from}-#{ip_range.last}"]
      if ip_range_shift > 0
        reserved_ips << "#{ip_range.nth(2)}-#{ip_range.nth(ip_range_shift+1)}"
      end

      cloud_config['networks'].first['subnets'] = [{
          'range' => ip_range.to_s,
          'gateway' => ip_range.nth(1),
          'dns' => [],
          'static' => [],
          'reserved' => reserved_ips,
          'cloud_properties' => {},
        }]
      cloud_config
    end

    def self.errand_manifest(opts)
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: opts.fetch(:name, 'errand'))
      manifest['jobs'] = [
        Bosh::Spec::Deployments.simple_errand_job.merge(
          'instances' => opts.fetch(:instances),
          'name' => 'errand_job'
        )
      ]
      manifest
    end
  end
end
