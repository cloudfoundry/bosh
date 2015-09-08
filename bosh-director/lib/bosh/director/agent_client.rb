require 'bosh/director/agent_message_converter'

module Bosh::Director
  class AgentClient

    PROTOCOL_VERSION = 2

    DEFAULT_POLL_INTERVAL = 1.0

    # in case of timeout errors
    GET_TASK_MAX_RETRIES = 2

    # get_task should retry at least once because some long running tasks
    # (e.g. configure_networks) will restart the agent (current implementation)
    # which most likely will result in first get_task message being lost
    # because agent was not listening on NATS and second retry message
    # will probably be received because agent came back up.
    GET_STATE_MAX_RETRIES = 2

    attr_accessor :id

    def self.with_defaults(id, options = {})
      vm = Bosh::Director::Models::Vm.find(:agent_id => id)
      with_vm(vm, options)
    end

    def self.with_vm(vm, options = {})
      defaults = {
        retry_methods: {
          get_state: GET_STATE_MAX_RETRIES,
          get_task: GET_TASK_MAX_RETRIES,
        }
      }

      credentials = vm.credentials
      defaults.merge!(credentials: credentials) if credentials

      self.new('agent', vm.agent_id, defaults.merge(options))
    end

    def initialize(service_name, client_id, options = {})
      @service_name = service_name
      @client_id = client_id
      @nats_rpc = Config.nats_rpc
      @timeout = options[:timeout] || 45
      @logger = Config.logger
      @retry_methods = options[:retry_methods] || {}

      if options[:credentials]
        @encryption_handler =
          Bosh::Core::EncryptionHandler.new(@client_id, options[:credentials])
      end

      @resource_manager = Api::ResourceManager.new
    end

    def method_missing(method_name, *args)
      handle_message_with_retry(method_name, *args)
    end

    def get_state(*args)
      send_message(:get_state, *args)
    end

    def cancel_task(*args)
      send_message(:cancel_task, *args)
    end

    def list_disk(*args)
      send_message(:list_disk, *args)
    end

    def prepare_configure_networks(*args)
      send_message(:prepare_configure_networks, *args)
    end

    def prepare_network_change(*args)
      send_message(:prepare_network_change, *args)
    end

    def start(*args)
      send_message(:start, *args)
    end

    def prepare(*args)
      send_message(:prepare, *args)
    end

    def apply(*args)
      send_message(:apply, *args)
    end

    def compile_package(*args)
      send_message(:compile_package, *args)
    end

    def drain(*args)
      send_message(:drain, *args)
    end

    def fetch_logs(*args)
      send_message(:fetch_logs, *args)
    end

    def migrate_disk(*args)
      send_message(:migrate_disk, *args)
    end

    def mount_disk(*args)
      send_message(:mount_disk, *args)
    end

    def unmount_disk(*args)
      send_message(:unmount_disk, *args)
    end

    def update_settings(certs)
      begin
        send_message(:update_settings, {"trusted_certs" => certs})
      rescue RpcRemoteException => e
        if e.message =~ /unknown message/
          @logger.warn("Ignoring update_settings 'unknown message' error from the agent: #{e.inspect}")
        else
          raise
        end
      end
    end

    def run_script(script_name, options)
      begin
        send_message(:run_script, script_name, options)
      rescue RpcRemoteException => e
        if e.message =~ /unknown message/
          @logger.warn("Ignoring run_script 'unknown message' error from the agent: #{e.inspect}. Received while trying to run: #{script_name}")
        else
          raise
        end
      end
    end

    def stop(*args)
      send_message(:stop, *args)
    end

    def run_errand(*args)
      start_task(:run_errand, *args)
    end

    def wait_for_task(agent_task_id, &blk)
      task = get_task_status(agent_task_id)

      while task['state'] == 'running'
        blk.call if block_given?
        sleep(DEFAULT_POLL_INTERVAL)
        task = get_task_status(agent_task_id)
      end

      task['value']
    end

    def configure_networks(*args)
      send_message(:configure_networks, *args)
    end

    def wait_until_ready(deadline = 600)
      old_timeout = @timeout
      @timeout = 1.0
      @deadline = Time.now.to_i + deadline

      begin
        ping
      rescue RpcTimeout
        retry if @deadline - Time.now.to_i > 0
        raise RpcTimeout, "Timed out pinging to #{@client_id} after #{deadline} seconds"
      rescue RpcRemoteException => e
        retry if e.message =~ /^restarting agent/ && @deadline - Time.now.to_i > 0
        raise e
      ensure
        @timeout = old_timeout
      end
    end

    def handle_method(method_name, args)
      result = {}
      result.extend(MonitorMixin)

      cond = result.new_cond
      timeout_time = Time.now.to_f + @timeout

      request = { :protocol => PROTOCOL_VERSION, :method => method_name, :arguments => args }

      if @encryption_handler
        @logger.info("Request: #{request}")
        request = { "encrypted_data" => @encryption_handler.encrypt(request) }
        request["session_id"] = @encryption_handler.session_id
      end

      recipient = "#{@service_name}.#{@client_id}"

      request_id = @nats_rpc.send_request(recipient, request) do |response|
        if @encryption_handler
          begin
            response = @encryption_handler.decrypt(response["encrypted_data"])
          rescue Bosh::Core::EncryptionHandler::CryptError => e
            response["exception"] = "CryptError: #{e.inspect} #{e.backtrace}"
          end
          @logger.info("Response: #{response}")
        end

        result.synchronize do
          inject_compile_log(response)
          result.merge!(response)
          cond.signal
        end
      end

      result.synchronize do
        while result.empty?
          timeout = timeout_time - Time.now.to_f
          unless timeout > 0
            @nats_rpc.cancel_request(request_id)
            raise RpcTimeout,
              "Timed out sending `#{method_name}' to #{@client_id} " +
                "after #{@timeout} seconds"
          end
          cond.wait(timeout)
        end
      end

      if result.has_key?("exception")
        raise RpcRemoteException, format_exception(result["exception"])
      end

      result["value"]
    end

    # Returns formatted exception information
    # @param [Hash|#to_s] exception Serialized exception
    # @return [String]
    def format_exception(exception)
      return exception.to_s unless exception.is_a?(Hash)

      msg = exception["message"].to_s

      if exception["backtrace"]
        msg += "\n"
        msg += Array(exception["backtrace"]).join("\n")
      end

      if exception["blobstore_id"]
        blob = download_and_delete_blob(exception["blobstore_id"])
        msg += "\n"
        msg += blob.to_s
      end

      msg
    end

    private

    # the blob is removed from the blobstore once we have fetched it,
    # but if there is a crash before it is injected into the response
    # and then logged, there is a chance that we lose it
    def inject_compile_log(response)
      if response["value"] && response["value"].is_a?(Hash) &&
        response["value"]["result"].is_a?(Hash) &&
        blob_id = response["value"]["result"]["compile_log_id"]
        compile_log = download_and_delete_blob(blob_id)
        response["value"]["result"]["compile_log"] = compile_log
      end
    end

    # Downloads blob and ensures it's deleted from the blobstore
    # @param [String] blob_id Blob id
    # @return [String] Blob contents
    def download_and_delete_blob(blob_id)
      blob = @resource_manager.get_resource(blob_id)
      blob
    ensure
      @resource_manager.delete_resource(blob_id)
    end

    def handle_message_with_retry(message_name, *args)
      retries = @retry_methods[message_name] || 0
      begin
        handle_method(message_name, args)
      rescue RpcTimeout
        if retries > 0
          retries -= 1
          retry
        end
        raise
      end
    end

    def send_message(method_name, *args, &blk)
      task = start_task(method_name, *args)
      if task['agent_task_id']
        wait_for_task(task['agent_task_id'], &blk)
      else
        task['value']
      end
    end

    def start_task(method_name, *args)
      AgentMessageConverter.convert_old_message_to_new(handle_message_with_retry(method_name, *args))
    end

    def get_task_status(agent_task_id)
      AgentMessageConverter.convert_old_message_to_new(get_task(agent_task_id))
    end
  end
end
