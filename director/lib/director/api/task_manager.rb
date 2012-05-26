# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class TaskManager
      # Looks up director task in DB
      # @param [Integer] task_id
      # @return [Models::Task] Task
      # @raise [TaskNotFound]
      def find_task(task_id)
        task = Models::Task[task_id]
        if task.nil?
          raise TaskNotFound, "Task #{task_id} not found"
        end
        task
      end

      # Returns hash representation of the task
      # @param [Models::Task] task Director task
      # @return [Hash] Hash task representation
      def task_to_hash(task)
        {
          "id" => task.id,
          "state" => task.state,
          "description" => task.description,
          "timestamp" => task.timestamp.to_i,
          "result" => task.result,
          "user" => task.user ? task.user.username : "admin"
        }
      end
    end
  end
end