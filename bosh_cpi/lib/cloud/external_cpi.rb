require 'membrane'
require 'open3'

module Bosh::Clouds
  class ExternalCpi
    ##
    # Raised when the external CPI executable returns an error unknown to director
    #
    class UnknownError < StandardError; end

    ##
    # Raised when the external CPI executable returns nil or invalid JSON format to director
    class InvalidResponse < StandardError; end

    ##
    # Raised when the external CPI bin/cpi is not executable
    class NonExecutable < StandardError; end

    KNOWN_RPC_ERRORS = %w(
      Bosh::Clouds::VMCreationFailed
      Bosh::Clouds::DiskNotFound
      Bosh::Clouds::DiskNotAttached
      Bosh::Clouds::NoDiskSpace
      Bosh::Clouds::CloudError
      Bosh::Clouds::CpiError
    ).freeze

    KNOWN_RPC_METHODS = %w(
      current_vm_id
      create_stemcell
      delete_stemcell
      create_vm
      delete_vm
      has_vm?
      reboot_vm
      set_vm_metadata
      configure_networks
      create_disk
      delete_disk
      attach_disk
      detach_disk
      snapshot_disk
      delete_snapshot
      get_disks
      ping
    ).freeze

    RESPONSE_SCHEMA = Membrane::SchemaParser.parse do
      {
        'result' => any,
        'error' => enum(nil,
          { 'type' => String,
            'message' => String,
            'ok_to_retry' => bool
          }
        )
      }
    end

    def initialize(cpi_path)
      @cpi_path = cpi_path
    end

    KNOWN_RPC_METHODS.each do |method_name|
      define_method method_name do |*arguments|
        opts = JSON.dump({
          'method' => method_name.gsub(/\?$/,''),
          'arguments' => arguments
        })

        env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => ENV['TMPDIR']}
        cpi_exec_path = checked_cpi_exec_path

        _, stdout, _, _ = Open3.popen3(env, "#{cpi_exec_path} #{opts}")

        response = parsed_response(stdout)
        validate_response(response)

        if response['error']
          handle_error(response['error'])
        end

        response['result']
      end
    end

    private

    def checked_cpi_exec_path
      cpi_exec_path = "#{@cpi_path}/bin/cpi"
      unless File.executable?(cpi_exec_path)
        raise NonExecutable, "Failed to run cpi: `#{cpi_exec_path}' is not executable"
      end
      cpi_exec_path
    end

    def handle_error(error_response)
      error_type = error_response['type']
      error_message = error_response['message']
      unless KNOWN_RPC_ERRORS.include?(error_type)
        raise UnknownError, "Received unknown error from cpi: #{error_type} with message #{error_message}"
      end

      error_class = constantize(error_type)

      if error_class <= RetriableCloudError
        error = error_class.new(error_response['ok_to_retry'])
      else
        error = error_class.new(error_message)
      end

      raise error, error_message
    end

    def parsed_response(input)
      begin
        JSON.load(input)
      rescue JSON::ParserError => e
        raise InvalidResponse, "Received invalid response from cpi with error #{e.message}"
      end
    end

    def validate_response(response)
      RESPONSE_SCHEMA.validate(response)
    rescue Membrane::SchemaValidationError => e
      raise InvalidResponse, "Received invalid response from cpi with error #{e.message}"
    end

    def constantize(camel_cased_word)
      error_name = camel_cased_word.split('::').last
      Bosh::Clouds.const_get(error_name)
    end
  end
end
