# encoding: UTF-8

module Bosh
  module Agent
    class BaseClient

      def run_task(method, *args)
        task = send(method.to_sym, *args)

        while task['state'] == 'running'
          sleep(1.0)
          task = get_task(task['agent_task_id'])
        end

        task
      end

      def method_missing(method_name, *args)
        result = handle_method(method_name, args)

        raise HandlerError, result['exception'] if result.has_key?('exception')
        result['value']
      end

      protected

      def handle_method(method_name, args)
      end
    end
  end
end
