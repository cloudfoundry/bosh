require 'json'

class Bosh::Cpi::Cli
  KNOWN_RPC_METHODS = %w(
    current_vm_id
    create_stemcell
    delete_stemcell
    create_vm
    delete_vm
    has_vm
    reboot_vm
    set_vm_metadata
    configure_networks
    create_disk
    has_disk
    delete_disk
    attach_disk
    detach_disk
    snapshot_disk
    delete_snapshot
    get_disks
    ping
  ).freeze

  RPC_METHOD_TO_RUBY_METHOD = {
    'has_vm' => 'has_vm?',
    'has_disk' => 'has_disk?',
  }.freeze

  INVALID_CALL_ERROR_TYPE = 'InvalidCall'.freeze
  UNKNOWN_ERROR_TYPE      = 'Unknown'.freeze

  def initialize(cpi, logs_string_io, result_io)
    @cpi = cpi
    @logs_string_io = logs_string_io
    @result_io = result_io
  end

  def run(json)
    begin
      request = JSON.load(json)
    rescue JSON::ParserError => e
      return error_response(INVALID_CALL_ERROR_TYPE, "Request cannot be deserialized, details: #{e.message}", false, e.backtrace)
    end

    method = request['method']
    unless method.is_a?(String)
      return error_response(INVALID_CALL_ERROR_TYPE, "Method must be a String, got: '#{method.inspect}'", false)
    end

    unless KNOWN_RPC_METHODS.include?(method)
      return error_response(INVALID_CALL_ERROR_TYPE, "Method is not known, got: '#{method}'", false)
    end

    arguments = request['arguments']
    unless arguments.is_a?(Array)
      return error_response(INVALID_CALL_ERROR_TYPE, "Arguments must be an Array, got: '#{arguments.inspect}'", false)
    end

    context = request['context']
    unless context.is_a?(Hash) && context['director_uuid'].is_a?(String)
      return error_response(INVALID_CALL_ERROR_TYPE, "Request should include context with director uuid, got: '#{context.inspect}'", false)
    end

    configure_director(context['director_uuid'])

    ruby_method = RPC_METHOD_TO_RUBY_METHOD[method] || method

    begin
      cpi = @cpi.call
      result = cpi.public_send(ruby_method, *arguments)
    rescue Bosh::Clouds::RetriableCloudError => e
      return error_response(error_name(e), e.message, e.ok_to_retry, e.backtrace)
    rescue Bosh::Clouds::CloudError, Bosh::Clouds::CpiError => e
      return error_response(error_name(e), e.message, false, e.backtrace)
    rescue ArgumentError => e
      return error_response(INVALID_CALL_ERROR_TYPE, "Arguments are not correct, details: '#{e.message}'", false, e.backtrace)
    rescue Exception => e
      return error_response(UNKNOWN_ERROR_TYPE, e.message, false, e.backtrace)
    end

    result_response(result)
  end

  private

  def configure_director(director_uuid)
    Bosh::Clouds::Config.uuid = director_uuid
  end

  def error_response(type, message, ok_to_retry, bt=[])
    if !bt.empty?
      @logs_string_io.print("Rescued #{type}: #{message}. backtrace: #{bt.join("\n")}")
    end

    hash = {
      result: nil,
      error: {
        type: type,
        message: message,
        ok_to_retry: ok_to_retry,
      },
      log: @logs_string_io.string,
    }
    @result_io.print(JSON.dump(hash)); nil
  end

  def result_response(result)
    hash = {
      result: result,
      error: nil,
      log: @logs_string_io.string,
    }
    @result_io.print(JSON.dump(hash)); nil
  end

  def error_name(error)
    error.class.name
  end
end
