# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    module CloudCheck
      class Scan < BaseJob
        include LockHelper

        @queue = :normal

        # @param [String] deployment_name Deployment name
        def initialize(deployment_name)
          super

          @deployment_manager = Api::DeploymentManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)
        end

        def perform
          begin
            with_deployment_lock(@deployment, :timeout => 0) do
              scanner = ProblemScanner.new(@deployment)
              scanner.reset
              scanner.scan_vms
              scanner.scan_disks

              "scan complete"
            end
          rescue Lock::TimeoutError
            raise "Unable to get deployment lock, maybe a deployment is in progress. Try again later."
          end
        end
      end
    end
  end
end
