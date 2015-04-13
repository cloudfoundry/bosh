require 'yaml'
require 'common/exec'

module Bat
  class Stemcell
    include Bosh::Exec

    attr_reader :path
    attr_reader :name
    attr_reader :cpi
    attr_reader :version

    def self.from_path(path)
      Dir.mktmpdir do |dir|
        sh("tar xzf #{path} --directory=#{dir} stemcell.MF")
        stemcell_manifest = "#{dir}/stemcell.MF"
        st = YAML.load_file(stemcell_manifest)
        Stemcell.new(st['name'], st['version'], st['cloud_properties']['infrastructure'], path)
      end
    end

    def initialize(name, version, cpi = nil, path = nil)
      @name = name
      @version = version
      @cpi = cpi
      @path = path
    end

    def to_s
      "#{name}-#{version}"
    end

    def to_path
      path
    end

    def supports_network_reconfiguration?
      !(name =~ /vsphere/ && (name =~ /centos/ || name !~ /go_agent/)) && name !~ /vcloud/ && name !~ /warden/
    end

    def sudo_command
      if name =~ /centos/
        "echo #{ENV['BAT_VCAP_PASSWORD']} | sudo -S -p '' -i"
      else
        "echo #{ENV['BAT_VCAP_PASSWORD']} | sudo -S -p '' -s"
      end
    end

    def supports_root_partition?
      !!(name =~ /openstack/ && name !~ /centos/)
    end

    def supports_changing_static_ip?(network_type)
      # Does not support for openstack dynamic
      supports_network_reconfiguration? && !(name =~ /openstack/ && network_type == 'dynamic')
    end

    def supports_multiple_manual_networks?
      name =~ /openstack/ && name =~ /ubuntu/ && name =~ /go_agent/
    end

    def ==(other)
      to_s == other.to_s
    end
  end
end
