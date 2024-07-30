require 'ipaddr'

module Bosh::Spec
  class NetworkingManifest
    def self.deployment_manifest(opts={})
      job_opts = {}
      job_opts[:instances] = opts[:instances] if opts[:instances]
      job_opts[:static_ips] = opts[:static_ips] if opts[:static_ips]

      job_opts[:jobs] = [{ 'name' => opts[:job], 'release' => opts.fetch(:job_release, 'bosh-release') }] if opts[:job]
      manifest = opts.fetch(:manifest, Bosh::Spec::Deployments.simple_manifest_with_instance_groups)
      manifest['instance_groups'] = [Bosh::Spec::Deployments.simple_instance_group(job_opts)]

      manifest['name'] = opts.fetch(:name, 'simple')

      manifest
    end

    def self.cloud_config(opts)
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config['networks'].first['subnets'] = [make_subnet(opts)]
      cloud_config
    end

    def self.make_subnet(opts)
      range_string = opts.fetch(:range, '192.168.1.0/24')

      range_ip_addr = IPAddr.new(range_string)
      ip_range = range_ip_addr.to_range.to_a
      ip_range_shift = opts.fetch(:shift_ip_range_by, 0)
      available_ips = opts.fetch(:available_ips)
      raise "not enough IPs, don't be so greedy" if available_ips > ip_range.size

      ip_to_reserve_from = ip_range[available_ips + 2 + ip_range_shift] # first IP is gateway, range is inclusive, so +2
      reserved_ips = ["#{ip_to_reserve_from}-#{ip_range.last}"]
      if ip_range_shift > 0
        reserved_ips << "#{ip_range[2]}-#{ip_range[ip_range_shift + 1]}"
      end

      {
        'range' => range_string,
        'gateway' => ip_range[1],
        'dns' => [],
        'static' => [],
        'reserved' => reserved_ips,
        'cloud_properties' => {},
      }
    end

    def self.errand_manifest(opts)
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: opts.fetch(:name, 'errand'))
      manifest['instance_groups'] = [
        Bosh::Spec::Deployments.simple_errand_instance_group.merge(
          'instances' => opts.fetch(:instances),
          'name' => 'errand_job'
        )
      ]
      manifest
    end
  end
end
