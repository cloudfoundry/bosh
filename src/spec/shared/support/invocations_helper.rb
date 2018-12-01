module Support
  module InvocationsHelper
    CPI_TARGET = 'cpi'.freeze
    AGENT_TARGET = 'agent'.freeze

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
          invocations << CPIInvocation.new(
            cpi_invocation_lookup[JSON.parse(match[2])['context']['request_id']],
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
    end

    class CPIInvocation < Invocation
      attr_reader :response

      def initialize(cpi_call, response)
        super(CPI_TARGET, cpi_call.method_name, cpi_call.inputs)
        @response = response
      end
    end

    class AgentInvocation < Invocation
      attr_reader :agent_id

      def initialize(agent_id, agent_call)
        super(AGENT_TARGET, agent_call['method'], agent_call['arguments'])
        @agent_id = agent_id
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

RSpec::Matchers.define :be_cpi_call do |message:, argument_matcher: nil|
  match do |actual|
    matches = actual.target == Support::InvocationsHelper::CPI_TARGET && actual.method == message
    matches &&= argument_matcher.matches?(actual.arguments) unless argument_matcher.nil?
    matches
  end
  failure_message do |actual|
    unless argument_matcher.nil?
      with_args = " with '#{actual.arguments.inspect}'"
      with_args_matching = " with arguments matching '#{argument_matcher.expected}'"
    end

    "expected cpi to receive message '#{message}'#{with_args_matching} "\
      "but #{actual.target} received message '#{actual.method}'#{with_args}"
  end
end

RSpec::Matchers.define :be_agent_call do |message:, argument_matcher: nil, agent_id: nil|
  match do |actual|
    matches = actual.target == Support::InvocationsHelper::AGENT_TARGET && actual.method == message
    matches &&= argument_matcher.matches?(actual.arguments) unless argument_matcher.nil?
    matches &&= actual.agent_id == agent_id unless agent_id.nil?
    matches
  end
  failure_message do |actual|
    unless argument_matcher.nil?
      with_args = " with '#{actual.arguments.inspect}'"
      with_args_matching = " with arguments matching '#{argument_matcher.expected}'"
    end

    "expected agent to receive message '#{message}'#{with_args_matching} "\
      "but #{actual.target} received message '#{actual.method}'#{with_args}"
  end
end
