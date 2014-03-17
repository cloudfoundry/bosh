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
  }.freeze

  INVALID_CALL_ERROR_TYPE = 'InvalidCall'.freeze
  UNKNOWN_ERROR_TYPE      = 'Unknown'.freeze

  def initialize(cpi, result_io)
    @cpi = cpi
    @result_io = result_io
  end

  def run(json)
    begin
      request = JSON.load(json)
    rescue JSON::ParserError
      return error_response(INVALID_CALL_ERROR_TYPE, 'Request cannot be deserialized', false)
    end

    method = request['method']
    unless method.is_a?(String)
      return error_response(INVALID_CALL_ERROR_TYPE, 'Method must be a String', false)
    end

    unless KNOWN_RPC_METHODS.include?(method)
      return error_response(INVALID_CALL_ERROR_TYPE, 'Method is not known', false)
    end

    arguments = request['arguments']
    unless arguments.is_a?(Array)
      return error_response(INVALID_CALL_ERROR_TYPE, 'Arguments must be an Array', false)
    end

    ruby_method = RPC_METHOD_TO_RUBY_METHOD[method] || method

    begin
      result = @cpi.public_send(ruby_method, *arguments)
    rescue Bosh::Clouds::RetriableCloudError => e
      return error_response(error_name(e), e.message, e.ok_to_retry)
    rescue Bosh::Clouds::CloudError, Bosh::Clouds::CpiError => e
      return error_response(error_name(e), e.message, false)
    rescue ArgumentError
      return error_response(INVALID_CALL_ERROR_TYPE, 'Arguments are not correct', false)
    rescue Exception => e
      return error_response(UNKNOWN_ERROR_TYPE, e.message, false)
    end

    result_response(result)
  end

  private

  def error_response(type, message, ok_to_retry)
    hash = {
      result: nil,
      error: {
        type: type,
        message: message,
        ok_to_retry: ok_to_retry,
      },
    }
    @result_io.print(JSON.dump(hash)); nil
  end

  def result_response(result)
    hash = {
      result: result,
      error: nil,
    }
    @result_io.print(JSON.dump(hash)); nil
  end

  def error_name(error)
    error.class.name
  end
end
