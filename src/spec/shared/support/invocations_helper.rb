module Support
  module InvocationsHelper
    CPI_TARGET = 'cpi'.freeze
    AGENT_TARGET = 'agent'.freeze

    def cid_and_agent(vm_creation_call)
      [vm_creation_call.response, vm_creation_call.arguments['agent_id']]
    end

    def filter_invocations(invocations, agent_ids: [], vm_cids: [])
      invocations.select do |i|
        (i.target == 'agent' && agent_ids.include?(i.agent_id)) ||
          (i.target == 'cpi' && agent_ids.include?(i.arguments.try(:[], 'agent_id'))) ||
          (i.target == 'cpi' && vm_cids.include?(i.arguments.try(:[], 'vm_cid')))
      end
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
        arguments&.fetch('disk_id', '')
      end

      def to_hash(show_arguments = false)
        {
          target: target,
          method: method,
          agent_id: agent_id,
          vm_cid: vm_cid,
          disk_id: disk_id,
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

      def to_hash(show_arguments = false)
        {
          target: target,
          method: method,
          agent_id: agent_id,
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
  config.include(Support::InvocationsHelper)
end

RSpec::Matchers.define :be_sequence_of_calls do |*original_calls|
  next_actual_call = {}
  next_expected_call = {}
  calls = original_calls.dup
  index = 0
  did_fail_match = false

  match do |original_actual|
    actual = original_actual.dup
    matches = true

    until calls.empty?
      if actual.empty?
        matches = false
        break
      end
      next_actual_call = actual.shift
      next_expected_call = calls.shift
      matches &&= next_actual_call.target == next_expected_call[:target]
      matches &&= next_actual_call.method == next_expected_call[:method]

      if next_expected_call.key? :argument_matcher
        matches &&= next_expected_call[:argument_matcher].matches?(next_actual_call.arguments)
      end

      if next_expected_call.key? :response_matcher
        matches &&= next_expected_call[:response_matcher].matches?(next_actual_call.response)
      end

      if next_expected_call.key? :agent_id
        matches &&= next_actual_call.agent_id == next_expected_call[:agent_id]
      end

      if next_expected_call.key? :vm_cid
        matches &&= next_actual_call.vm_cid == next_expected_call[:vm_cid]
      end

      unless matches
        did_fail_match = true
        break
      end

      if next_expected_call[:can_repeat]
        actual = actual.drop_while { |i| i.to_hash == next_actual_call.to_hash }
      end

      index += 1
    end
    matches && actual.empty?
  end

  failure_message do |actual|
    if did_fail_match
      "expected at index #{index} call did not match:\n" \
        "  expected:\n    #{next_expected_call.inspect}\n  actual:\n    #{next_actual_call.to_hash(true).inspect}\n\n"  \
        "  actual calls:\n    #{actual.map(&:to_hash).map(&:inspect).join("\n    ")}"
    else
      "expected a sequence of length #{original_calls.length}#{calls.any? { |i| i[:can_repeat] } ? '+' : ''} " \
        "but got a differing sequence of length #{actual.length}: \n" \
        "#{actual.map(&:to_hash).map(&:inspect).join("\n")}"
    end
  end
end
