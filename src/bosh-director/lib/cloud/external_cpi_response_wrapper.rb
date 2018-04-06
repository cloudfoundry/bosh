module Bosh::Clouds
  class ExternalCpiResponseWrapper
    def initialize(cpi, cpi_api_version)
      @cpi = cpi
      @cpi_api_version = cpi_api_version
      @cpi.request_cpi_api_version = @cpi_api_version
    end

    def current_vm_id(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
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
    def get_disks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def ping(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def calculate_vm_cloud_properties(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def info; invoke_cpi_method(__method__.to_s); end

    def invoke_cpi_method(method, *arguments)
      @cpi.public_send(method, *arguments)
    end

    def create_vm(*args)
      cpi_response = @cpi.create_vm(*args)

      response = []
      if @cpi_api_version >= 2
        response = cpi_response
      else
        response << cpi_response
      end

      response
    end

    def attach_disk(*args)
      if @cpi_api_version == 2 && args.count == 2
        args << {'disk_hints' => {}}
      end

      @cpi.attach_disk(*args)
    end
  end
end