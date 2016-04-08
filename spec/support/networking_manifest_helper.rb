module Bosh::Spec
  class NetworkingManifest
    def self.deployment_manifest(opts={})
      manifest = opts.fetch(:manifest, Bosh::Spec::Deployments.simple_manifest)
      manifest['name'] = opts.fetch(:name, 'simple')

      job_opts = {}
      job_opts[:templates] = [{'name' => opts[:template]}] if opts[:template]
      job_opts[:instances] = opts[:instances] if opts[:instances]
      job_opts[:static_ips] =opts[:static_ips] if opts[:static_ips]
      manifest['jobs'] = [Bosh::Spec::Deployments.simple_job(job_opts)]

      manifest
    end

    def self.legacy_deployment_manifest(opts)
      manifest = deployment_manifest(opts.merge(manifest: Bosh::Spec::Deployments.legacy_manifest))
      manifest['networks'].first['subnets'] = [make_subnet(opts)]
      manifest['networks'].first['subnets'].first['static'] = opts.fetch(:static_ips, [])
      manifest
    end

    def self.cloud_config(opts)
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config['networks'].first['subnets'] = [make_subnet(opts)]
      cloud_config
    end

    def self.make_subnet(opts)
      range = opts.fetch(:range, '192.168.1.0/24')
      ip_range = NetAddr::CIDR.create(range)
      ip_range_shift = opts.fetch(:shift_ip_range_by, 0)
      available_ips = opts.fetch(:available_ips)
      raise "not enough IPs, don't be so greedy" if available_ips > ip_range.size

      ip_to_reserve_from = ip_range.nth(available_ips+2+ip_range_shift) # first IP is gateway, range is inclusive, so +2
      reserved_ips = ["#{ip_to_reserve_from}-#{ip_range.last}"]
      if ip_range_shift > 0
        reserved_ips << "#{ip_range.nth(2)}-#{ip_range.nth(ip_range_shift+1)}"
      end

      {
        'range' => ip_range.to_s,
        'gateway' => ip_range.nth(1),
        'dns' => [],
        'static' => [],
        'reserved' => reserved_ips,
        'cloud_properties' => {},
      }
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
