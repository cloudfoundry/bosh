require 'membrane'
require 'open3'

module Bosh::Clouds
  class ExternalCpi
    # Raised when the external CPI executable returns an error unknown to director
    class UnknownError < StandardError; end

    # Raised when the external CPI executable returns nil or invalid JSON format to director
    class InvalidResponse < StandardError; end

    # Raised when the external CPI bin/cpi is not executable
    class NonExecutable < StandardError; end

    KNOWN_RPC_ERRORS = %w(
      Bosh::Clouds::CpiError
      Bosh::Clouds::NotSupported
      Bosh::Clouds::NotImplemented

      Bosh::Clouds::CloudError
      Bosh::Clouds::VMNotFound

      Bosh::Clouds::NoDiskSpace
      Bosh::Clouds::DiskNotAttached
      Bosh::Clouds::DiskNotFound
      Bosh::Clouds::VMCreationFailed
    ).freeze

    RESPONSE_SCHEMA = Membrane::SchemaParser.parse do
      {
        'result' => any,
        'error' => enum(nil,
          { 'type' => String,
            'message' => String,
            'ok_to_retry' => bool
          }
        ),
        'log' => String
      }
    end

    def initialize(cpi_path, director_uuid)
      @cpi_path = cpi_path
      @director_uuid = director_uuid
      @logger = Config.logger
    end

    def current_vm_id(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_vm?(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def reboot_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_vm_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def configure_networks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_disk?(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def attach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def detach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def snapshot_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_snapshot(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def get_disks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def ping(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end

    private

    def invoke_cpi_method(method_name, *arguments)
      request = JSON.dump({
          'method' => method_name.gsub(/\?$/,''),
          'arguments' => arguments,
          'context' => {
            'director_uuid' => @director_uuid
          }
        })

      env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => ENV['TMPDIR']}
      cpi_exec_path = checked_cpi_exec_path

      @logger.debug("External CPI sending request: #{request} with command: #{cpi_exec_path}")
      cpi_response, stderr, exit_status = Open3.capture3(env, cpi_exec_path, stdin_data: request, unsetenv_others: true)
      @logger.debug("External CPI got response: #{cpi_response}, err: #{stderr}, exit_status: #{exit_status}")

      parsed_response = parsed_response(cpi_response)
      validate_response(parsed_response)

      if parsed_response['error']
        handle_error(parsed_response['error'])
      end

      save_cpi_log(parsed_response['log'])

      parsed_response['result']
    end

    def checked_cpi_exec_path
      unless File.executable?(@cpi_path)
        raise NonExecutable, "Failed to run cpi: `#{@cpi_path}' is not executable"
      end
      @cpi_path
    end

    def handle_error(error_response)
      error_type = error_response['type']
      error_message = error_response['message']
      unless KNOWN_RPC_ERRORS.include?(error_type)
        raise UnknownError, "Unknown CPI error '#{error_type}' with message '#{error_message}'"
      end

      error_class = constantize(error_type)

      if error_class <= RetriableCloudError
        error = error_class.new(error_response['ok_to_retry'])
      else
        error = error_class.new(error_message)
      end

      raise error, error_message
    end

    def save_cpi_log(output)
      # cpi log path is set up at the beginning of every task in Config
      # see JobRunner#setup_task_logging
      File.open(Config.cpi_task_log, 'a') do |f|
        f.write(output)
      end
    end

    def parsed_response(input)
      begin
        JSON.load(input)
      rescue JSON::ParserError => e
        raise InvalidResponse, "Invalid CPI response - ParserError - #{e.message}"
      end
    end

    def validate_response(response)
      RESPONSE_SCHEMA.validate(response)
    rescue Membrane::SchemaValidationError => e
      raise InvalidResponse, "Invalid CPI response - SchemaValidationError: #{e.message}"
    end

    def constantize(camel_cased_word)
      error_name = camel_cased_word.split('::').last
      Bosh::Clouds.const_get(error_name)
    end
  end
end
