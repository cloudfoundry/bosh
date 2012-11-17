
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
        stemcell_id = SecureRandom.uuid
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

    ##
    # Create a container in warden
    #
    # Limitaion: We don't support creating VM with multiple network nics.
    #
    # @param [String] agent_id UUID for bosh agent
    # @param [String] stemcell_id stemcell id
    # @param [Hash] resource_pool not used
    # @param [Hash] networks list of networks and their settings needed for this VM
    # @param [optional, String, Array] disk_locality not used
    # @param [optional, Hash] env environment that will be passed to this vm
    # @return [String] vm_id
    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      with_thread_name("create_vm(#{agent_id}, #{stemcell_id}, #{networks})") do

        stemcell_path = stemcell_path(stemcell_id)

        raise "Not support more than 1 nics" if networks.size > 1
        raise "Stemcell(#{stemcell_id}) not found" unless Dir.exist?(stemcell_path)

        vm = Models::VM.new

        # Create Container
        handle = with_warden do |client|
          request = Warden::Protocol::CreateRequest.new
          request.rootfs = File.join(stemcell_path, 'root')
          if networks.first[1]['type'] != 'dynamic'
            request.network = '1.1.1.1'
          end

          response = client.call(request)
          response.handle
        end

        # Agent settings
        env = generate_agent_env(vm, agent_id, networks)

        tempfile = Tempfile.new('settings')
        tempfile.write(yajl::Encoder.encode(env)) # TODO
        tempfile.close

        with_warden do |client|
          request = Warden::Protocol::CopyInRequest.new
          request.handle = handle
          request.src_path = tempfile.path
          request.dst_path = Bosh::Agent::Config.settings_file

          client.call(request)
        end

        # TODO start agent and other init scripts, something like power on

        # Save to DB
        vm.container_id = handle
        vm.save

        vm.id.to_s
      end
    rescue => e
      # TODO how to clean up
      cloud_error(e)
    end

    ##
    # Deletes a VM
    #
    # @param [String] vm_id vm id
    def delete_vm(vm_id)
      with_thread_name("delete_vm(#{vm_id})") do
        with_warden do |client|
          request = Warden::Protocol::DestroyRequest.new
          client.call(request)
        end

        Models::VM[vm_id.to_i].delete
      end

      # TODO remove vm_id from database
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
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

    def with_warden
      # TODO make sure client is running as root inside container
      client = Warden::Client.new(@warden_unix_path)
      client.connect
      ret = yield client
      client.disconnect

      ret
    end


    def generate_agent_env(vm, agent_id, networks)
      vm_env = {
        "name" => vm.container_id,
        "id" => vm.id
      }

      env = {
        "vm" => vm_env,
        "agent_id" => agent_id,
        "networks" => networks,
      }
      env
    end

  end
end
