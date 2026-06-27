module Bosh::Clouds
  class ExternalCpiResponseWrapper
    def initialize(cpi, cpi_api_version)
      @cpi = cpi
      @cpi_api_version = cpi_api_version
      @cpi.request_cpi_api_version = @cpi_api_version

      check_cpi_api_support
    end

    def current_vm_id(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_network(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_network(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def reboot_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_vm_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_disk_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def detach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def snapshot_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_snapshot(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def resize_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def update_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def get_disks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def ping(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def calculate_vm_cloud_properties(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def info; invoke_cpi_method(__method__.to_s); end

    def invoke_cpi_method(method, *arguments)
      @cpi.public_send(method, *arguments)
    end

    def create_vm(*args)
      @cpi.create_vm(*args)
    end

    def create_stemcell(*args)
      final_args = @cpi_api_version >= 3 ? args : args.take(2)
      @cpi.create_stemcell(*final_args)
    end

    def attach_disk(*args)
      cpi_response = @cpi.attach_disk(*args)
      raise Bosh::Clouds::AttachDiskResponseError, 'No disk_hint' if cpi_response.nil? || cpi_response.empty?
      cpi_response
    end

    private

    def check_cpi_api_support
      if @cpi_api_version < 2
        raise Bosh::Clouds::NotSupported, "CPI API version #{@cpi_api_version} is not supported. Minimum required version is 2."
      end
      if @cpi_api_version > Bosh::Director::Config.preferred_cpi_api_version
        raise Bosh::Clouds::NotSupported, "CPI API version #{@cpi_api_version} is not supported."
      end
    end
  end
end
