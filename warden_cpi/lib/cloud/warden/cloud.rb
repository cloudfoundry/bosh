
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"
    DEFAULT_STEMCELL_ROOT = "/var/vcap/stemcell"

    attr_accessor :logger

    ##
    # Initialize BOSH Warden CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"] || {}
      @stemcell_properties = options["stemcell"] || {}

      setup_warden
      setup_stemcell
    end

    ##
    # Create a stemcell using stemcell image
    # This method simply untar the stemcell image to a local directory. Warden
    # can use the rootfs within the image as a base fs.
    # @param [String] image_path local path to a stemcell image
    # @param [Hash] cloud_properties not used
    # return [String] stemcell id
    def create_stemcell(image_path, cloud_properties)
      not_used(cloud_properties)

      with_thread_name("create_stemcell(#{image_path}, _)") do
        stemcell_id = stemcell_uuid
        stemcell_path = stemcell_path(stemcell_id)

        # Extract to tarball
        @logger.info("Extracting stemcell from #{image_path} to #{stemcell_path}")
        FileUtils.mkdir_p(stemcell_path)
        Bosh::Exec.sh "tar -C #{stemcell_path} -xzf #{image_path} 2>&1"

        # TODO Verify if it is a valid stemcell

        stemcell_id
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Delete the stemcell
    # @param [String] id of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id}, _)") do
        stemcell_path = stemcell_path(stemcell_id)
        FileUtils.rm_rf(stemcell_path)
      end
    end

    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      # TODO to be implemented

      vm_uuid
    end

    def delete_vm(vm_id)
      # TODO to be implemented
    end

    def reboot_vm(vm_id)
      # no-op
    end

    def configure_networks(vm_id, networks)
      # no-op
    end

    def create_disk(size, vm_locality = nil)
      # vm_locality is a string, which might mean the disk_path

      disk_id = disk_uuid
      disk_path = "/tmp/disk/#{disk_id}"

      disk_id
    end

    def delete_disk(disk_id)
      # TODO to be implemented
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def validate_deployment(old_manifest, new_manifest)
      # no-op
    end

    private

    def not_used(var)
      # no-op
    end

    def stemcell_path(stemcell_id)
      File.join(@stemcell_root, stemcell_id)
    end

    def setup_warden
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK

      @client = Warden::Client.new(@warden_unix_path)
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

  end
end
