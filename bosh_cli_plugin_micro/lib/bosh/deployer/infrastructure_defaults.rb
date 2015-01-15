require 'bosh/deployer/infrastructure_defaults/aws'
require 'bosh/deployer/infrastructure_defaults/openstack'
require 'bosh/deployer/infrastructure_defaults/vcloud'
require 'bosh/deployer/infrastructure_defaults/vsphere'

# TODO: need to make this more generic
require 'bosh/deployer/infrastructure_defaults/azure'

module Bosh::Deployer::InfrastructureDefaults
  def self.merge_for(plugin, config)
    case plugin
      when 'aws'
        defaults = AWS
      when 'openstack'
        defaults = OPENSTACK
      when 'vcloud'
        defaults = VCLOUD
      when 'vsphere'
        defaults = VSPHERE

      # TODO: need to make this more generic
      when 'azure'
        defaults = AZURE
    end
    deep_merge(defaults, config)
  end

  private

  def self.deep_merge(src, dst)
    src.merge(dst) do |key, old, new|
      if new.respond_to?(:blank) && new.blank?
        old
      elsif old.kind_of?(Hash) && new.kind_of?(Hash)
        deep_merge(old, new)
      elsif old.kind_of?(Array) && new.kind_of?(Array)
        old.concat(new).uniq
      else
        new
      end
    end
  end
end

