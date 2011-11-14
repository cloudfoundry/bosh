module Bosh::Director
  module ProblemHandlers
    class HandlerError < StandardError; end

    class Base
      attr_reader :data
      attr_accessor :job # so we can checkpoint task

      def self.create_from_model(model)
        create_by_type(model.type, model.resource_id, model.data)
      end

      def self.create_by_type(type, resource_id, data)
        handler_class = Base.handlers[type.to_s]
        if handler_class.nil?
          raise "Cannot find handler for `#{type}' problem"
        end

        handler_class.new(resource_id, data)
      end

      # Problem state is  described by constructor parameters.
      # Problem handler can reach out to check if the problem
      # is still present and attempt to fix it by applying
      # a potential resolution tagged with one or more labels.
      def initialize(resource_id, data)
        @logger = Config.logger
        @event_log = Config.event_log
        @job = nil
      end

      def checkpoint
        @job.task_checkpoint if @job
      end

      def problem_still_exists?; end

      # Problem description
      def description; end

      def resolutions
        self.class.resolutions.map do |name|
          { :name => name.to_s, :plan => resolution_plan(name) }
        end
      end

      def resolution_plan(resolution)
        plan = self.class.plan_for(resolution)
        return nil if plan.nil?
        instance_eval(&plan)
      end

      def auto_resolution
        self.class.get_auto_resolution
      end

      # @param resolution desired resolution
      def apply_resolution(resolution)
        action = self.class.action_for(resolution)
        if action.nil?
          handler_error("Cannot find `#{resolution}' resolution for `#{self.class}'")
        end
        instance_eval(&action)
      end

      def auto_resolve
        apply_resolution(auto_resolution)
      end

      def handler_error(message)
        raise HandlerError, message
      end

      # Registration DSL
      class << self
        attr_accessor :handlers
      end

      def self.register_as(type)
        Base.handlers ||= {}
        Base.handlers[type.to_s] = self
      end

      # Resolution DSL
      class << self
        attr_reader :resolutions
      end

      def self.init_dsl_data
        @resolutions = []
        @plans = {}
        @actions = {}
        @auto_resolution = nil
      end

      init_dsl_data

      def self.inherited(base)
        base.class_eval { init_dsl_data }
      end

      def self.plan_for(resolution)
        @plans[resolution.to_s]
      end

      def self.action_for(resolution)
        @actions[resolution.to_s]
      end

      def self.plan(&block)
        @plans[@pending_name.to_s] = block
      end

      def self.action(&block)
        @actions[@pending_name.to_s] = block
      end

      def self.get_auto_resolution
        @auto_resolution
      end

      def self.auto_resolution(name)
        @auto_resolution = name
      end

      def self.resolution(name, &block)
        @resolutions << name
        @pending_name = name
        instance_eval(&block)
      ensure
        @pending_name = nil
      end

    end
  end
end

