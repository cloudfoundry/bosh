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

    def initialize(cpi_path, director_uuid, properties_from_cpi_config = nil)
      @cpi_path = cpi_path
      @director_uuid = director_uuid
      @logger = ::Bosh::Director::TaggedLogger.new(Config.logger, "external-cpi")
      @properties_from_cpi_config = properties_from_cpi_config
    end

    def current_vm_id(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_vm(*arguments) invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def reboot_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_vm_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_disk_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def attach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def detach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def snapshot_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_snapshot(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def resize_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def get_disks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def ping(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def info; invoke_cpi_method(__method__.to_s); end

    private

    def invoke_cpi_method(method_name, *arguments)
      request_id = "cpi-#{Random.rand(100000..999999)}"
      context = {
        'director_uuid' => @director_uuid,
        'request_id' => request_id
      }
      context.merge!(@properties_from_cpi_config) unless @properties_from_cpi_config.nil?

      request = request_json(method_name, arguments, context)
      redacted_request = request_json(method_name, redact_arguments(method_name, arguments), redact_context(context))

      env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => ENV['TMPDIR']}
      cpi_exec_path = checked_cpi_exec_path

      logger = ::Bosh::Director::TaggedLogger.new(@logger, request_id)

      logger.debug("request: #{redacted_request} with command: #{cpi_exec_path}")
      cpi_response, stderr, exit_status = Open3.capture3(env, cpi_exec_path, stdin_data: request, unsetenv_others: true)
      logger.debug("response: #{cpi_response}, err: #{stderr}, exit_status: #{exit_status}")

      parsed_response = parsed_response(cpi_response)
      validate_response(parsed_response)

      save_cpi_log(parsed_response['log'])
      save_cpi_log(stderr)

      if parsed_response['error']
        handle_error(parsed_response['error'], method_name)
      end

      parsed_response['result']
    end

    def checked_cpi_exec_path
      unless File.executable?(@cpi_path)
        raise NonExecutable, "Failed to run cpi: '#{@cpi_path}' is not executable"
      end
      @cpi_path
    end

    def redact_context(context)
      return context if @properties_from_cpi_config.nil?
      Hash[context.map{|k,v|[k,@properties_from_cpi_config.keys.include?(k) ? '<redacted>' : v]}]
    end

    def redact_arguments(method_name, arguments)
      if method_name == 'create_vm'
        arguments = redact_from_env_in_create_vm_arguments(arguments)
        redact_cloud_property_values(arguments, 2)
      elsif method_name == 'create_disk'
        redact_cloud_property_values(arguments, 1)
      else
        arguments
      end
    end

    def redact_cloud_property_values(arguments, position)
      redacted_arguments = arguments.clone
      cloud_properties = redacted_arguments[position]
      redacted_cloud_properties = redactAllBut([], cloud_properties)
      redacted_arguments[position] = redacted_cloud_properties
      redacted_arguments
    end

    def redact_from_env_in_create_vm_arguments(arguments)
      redacted_arguments = arguments.clone
      env = redacted_arguments[5]
      env = redactAllBut(['bosh'], env)
      env['bosh'] = redactAllBut(['group', 'groups'], env['bosh'])
      redacted_arguments[5] = env
      redacted_arguments
    end

    def redactAllBut(keys, hash)
      Hash[hash.map { |k,v| [k, keys.include?(k) ? v.dup : '<redacted>'] }]
    end

    def request_json(method_name, arguments, context)
      JSON.dump({
        'method' => method_name,
        'arguments' => arguments,
        'context' => context
      })
    end

    def handle_error(error_response, method_name)
      error_type = error_response['type']
      error_message = error_response['message']

      # backwards compatibility for CPIs returning different errors than 'NotImplemented' for not implemented methods
      handle_method_not_implemented(error_message, error_type, method_name)

      unless KNOWN_RPC_ERRORS.include?(error_type)
        raise UnknownError, "Unknown CPI error '#{error_type}' with message '#{error_message}' in '#{method_name}' CPI method"
      end

      error_class = constantize(error_type)

      if error_class <= RetriableCloudError
        error = error_class.new(error_response['ok_to_retry'])
      else
        error = error_class.new(error_message)
      end

      raise error, "CPI error '#{error_type}' with message '#{error_message}' in '#{method_name}' CPI method"
    end

    def handle_method_not_implemented(error_message, error_type, method_name)
      message = "CPI error '#{error_type}' with message '#{error_message}' in '#{method_name}' CPI method"

      raise Bosh::Clouds::NotImplemented, message if error_type == "InvalidCall" && error_message.start_with?('Method is not known, got')
      raise Bosh::Clouds::NotImplemented, message if error_type == 'Bosh::Clouds::CloudError' && error_message.start_with?('Invalid Method:')
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
