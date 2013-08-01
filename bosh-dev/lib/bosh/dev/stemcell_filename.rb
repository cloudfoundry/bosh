module Bosh::Dev
  class StemcellFilename
    def initialize(options)
      @name = options.fetch(:name, 'stemcell')
      @version = options.fetch(:version)
      @infrastructure = options.fetch(:infrastructure)
      @format = options.fetch(:format)
      @hypervisor = options.fetch(:hypervisor)
      @arch = options.fetch(:arch, 'amd64')
      @distro = options.fetch(:distro, 'ubuntu_lucid')
    end

    def filename
      parts = [@name, @version, @infrastructure, @format, @hypervisor,
               @arch, @distro]
      "#{parts.join('-')}.tgz"
    end
  end
end