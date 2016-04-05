require 'bosh/director/problem_scanner/problem_register'
require 'bosh/director/problem_scanner/disk_scan_stage'
require 'bosh/director/problem_scanner/vm_scan_stage'

module Bosh::Director
  module ProblemScanner
    class Scanner
      def initialize(deployment)
        @deployment = deployment
        @agent_disks = {}

        @instance_manager = Api::InstanceManager.new

        @logger = Config.logger
        @event_logger = EventLogger.new(Config.event_log, @logger)

        @problem_register = ProblemRegister.new(deployment, @logger)
      end

      def reset(vms=nil)
        if vms
          vms.each do |job, index|
            instance = @instance_manager.find_by_name(@deployment, job, index)

            Models::DeploymentProblem.where(
              deployment: @deployment,
              resource_id: instance.id,
              state: 'open'
            ).update(state: 'closed')

          end
        else
          Models::DeploymentProblem.where(
            state: 'open',
            deployment: @deployment
          ).update(state: 'closed')
        end
      end

      def scan_vms(vms=nil)
        vm_scanner = VmScanStage.new(
          @instance_manager,
          @problem_register,
          Config.cloud,
          @deployment,
          @event_logger,
          @logger
        )
        vm_scanner.scan(vms)

        @agent_disks = vm_scanner.agent_disks
      end

      def scan_disks
        disk_scanner = DiskScanStage.new(
          @agent_disks,
          @problem_register,
          Config.cloud,
          @deployment.id,
          @event_logger,
          @logger
        )
        disk_scanner.scan
      end
    end

    class EventLogger
      def initialize(event_log, logger)
        @event_log = event_log
        @logger = logger
        @event_log_stage = nil
      end

      def begin_stage(stage_name, n_steps)
        @event_log_stage = @event_log.begin_stage(stage_name, n_steps)
        @logger.info(stage_name)
      end

      def track_and_log(task, log = true)
        @event_log_stage.advance_and_track(task) do |ticker|
          @logger.info(task) if log
          yield ticker if block_given?
        end
      end
    end
  end
end
