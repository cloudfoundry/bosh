module Bosh::Director
  module Jobs
    class SnapshotDeployment < BaseJob
      @queue = :normal

      attr_reader :deployment

      def self.job_type
        :snapshot_deployment
      end

      def initialize(deployment_name, options = {})
        @deployment = deployment_manager.find_by_name(deployment_name)
        @options = options
        @errors = 0
      end

      def deployment_manager
        @deployment_manager ||= Bosh::Director::Api::DeploymentManager.new
      end

      def perform
        logger.info("taking snapshot of: #{deployment.name}")
        deployment.job_instances.each do |instance|
          snapshot(instance)
        end

        msg = "snapshots of deployment '#{deployment.name}' created"
        msg += ", with #{@errors} failure(s)" unless @errors == 0
        msg
      end

      def snapshot(instance)
        if instance.vm_cid.nil?
          logger.info('No vm attached to this instance, no snapshot; skipping')
          return
        end
        logger.info("taking snapshot of: #{instance.job}/#{instance.index} (#{instance.vm_cid})")
        Bosh::Director::Api::SnapshotManager.take_snapshot(instance, @options)
      rescue Bosh::Clouds::CloudError => e
        @errors += 1
        logger.error("failed to take snapshot of: #{instance.job}/#{instance.index} (#{instance.vm_cid}) - #{e.inspect}")
        send_alert(instance, e.inspect)
      end

      ERROR = 3

      def send_alert(instance, message)
        payload = {
            'id'         => 'director',
            'severity'   => ERROR,
            'title'      => 'director - snapshot failure',
            'summary'    => "failed to snapshot #{instance.job}/#{instance.index}: #{message}",
            'created_at' => Time.now.to_i
        }
        Bosh::Director::Config.nats_rpc.send_message('hm.director.alert', payload)
      end
    end
  end
end
