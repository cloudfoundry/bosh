module IntegrationSupport
  module InvocationsHelper
    CPI_TARGET = 'cpi'.freeze
    AGENT_TARGET = 'agent'.freeze

    def cid_and_agent(vm_creation_call)
      [vm_creation_call.response, vm_creation_call.arguments['agent_id']]
    end

    def get_invocations(task_output)
      cpi_invocation_lookup = current_sandbox.cpi.invocations.map { |i| [i.context['request_id'], i] }.to_h
      task_id = task_output.match(/^Task (\d+)$/)[1]
      task_debug = File.read("#{current_sandbox.sandbox_root}/boshdir/tasks/#{task_id}/debug")
      invocations = []
      cpi_and_agent_requests = /DirectorJobRunner: (?:\[external-(cpi)\] \[cpi-(\d+)\] request: ({.*}) with command:.*|SENT: (agent)\.([^ ]*) (.+))$/
      task_debug.scan(cpi_and_agent_requests).each do |match|
        if match[0] == CPI_TARGET
          request_id = match[1]

          response_match = task_debug.match(/DirectorJobRunner: \[external-cpi\] \[cpi-#{request_id}\] response: ({.*}).*/)
          cpi_invocation = cpi_invocation_lookup[JSON.parse(match[2])['context']['request_id']]
          next if cpi_invocation.method_name == 'info'

          invocations << CPIInvocation.new(
            cpi_invocation,
            JSON.parse(response_match.captures[0])['result'],
          )
        elsif match[3] == AGENT_TARGET
          agent_message = JSON.parse(match[5])
          next if agent_message['method'] == 'get_task'
          next if agent_message['method'] == 'get_state'

          invocations << AgentInvocation.new(match[4], agent_message)
        end
      end
      invocations
    end

    class Invocation
      attr_reader :target, :method, :arguments

      def initialize(target, method, arguments)
        @target = target
        @method = method
        @arguments = arguments
      end

      def get_arguments(show_arguments)
        show_arguments ? arguments : 'HIDDEN'
      end

      def vm_cid
        ''
      end

      def agent_id
        ''
      end

      def convert_reference(label, reference)
        reference.fetch(label, label)
      end
    end

    class CPIInvocation < Invocation
      attr_reader :response

      def initialize(cpi_call, response)
        super(CPI_TARGET, cpi_call.method_name, cpi_call.inputs)
        @response = response
      end

      def agent_id
        arguments&.fetch('agent_id', '')
      end

      def vm_cid
        arguments&.fetch('vm_cid', '')
      end

      def disk_id
        if arguments.is_a?(Hash)
          arguments.fetch('disk_cid', arguments.fetch('disk_id', ''))
        elsif arguments.is_a?(Array) && method =~ /disk/
          arguments.first
        else
          ''
        end
      end

      def to_hash(show_arguments = false, reference = {})
        {
          target: target,
          method: method,
          agent_id: convert_reference(agent_id, reference),
          vm_cid: convert_reference(vm_cid, reference),
          disk_id: convert_reference(disk_id, reference),
          arguments: get_arguments(show_arguments),
          response: response,
        }
      end
    end

    class AgentInvocation < Invocation
      attr_reader :agent_id

      def initialize(agent_id, agent_call)
        super(AGENT_TARGET, agent_call['method'], agent_call['arguments'])
        @agent_id = agent_id
      end

      def to_hash(show_arguments = false, reference = {})
        {
          target: target,
          method: method,
          agent_id: convert_reference(agent_id, reference),
          arguments: get_arguments(show_arguments),
        }
      end
    end

    class InvocationIterator
      START = 0

      def initialize(array)
        @array = array
        @index = START
      end

      def next
        result = @array[@index]
        @index += 1
        result
      end

      def size
        @array.size
      end
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationSupport::InvocationsHelper)
end
