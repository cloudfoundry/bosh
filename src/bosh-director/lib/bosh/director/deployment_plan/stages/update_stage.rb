module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateStage
        def initialize(base_job, deployment_plan, multi_instance_group_updater, dns_encoder)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @multi_instance_group_updater = multi_instance_group_updater
          @dns_encoder = dns_encoder
        end

        def perform
          begin
            @logger.info('Updating deployment')
            PreCleanupStage.new(@logger, @deployment_plan).perform
            UpdateActiveVmCpisStage.new(@logger, @deployment_plan).perform
            setup_stage.perform
            DownloadPackagesStage.new(@base_job, @deployment_plan).perform
            UpdateInstanceGroupsStage.new(@base_job, @deployment_plan, @multi_instance_group_updater).perform
            UpdateErrandsStage.new(@base_job, @deployment_plan).perform
            @logger.info('Committing updates')
            PersistDeploymentStage.new(@deployment_plan).perform
            @logger.info('Finished updating deployment')
          ensure
            CleanupStemcellReferencesStage.new(@deployment_plan).perform
          end
        end

        private

        def vm_creator
          return @vm_creator if @vm_creator
          template_blob_cache = @deployment_plan.template_blob_cache
          agent_broadcaster = AgentBroadcaster.new
          vm_deleter = Bosh::Director::VmDeleter.new(@logger, false, Config.enable_virtual_delete_vms)
          @vm_creator = Bosh::Director::VmCreator.new(@logger, template_blob_cache, @dns_encoder, agent_broadcaster)
        end

        def setup_stage
          local_dns_repo = LocalDnsRepo.new(@logger, Config.root_domain)
          dns_publisher = BlobstoreDnsPublisher.new(
            lambda { App.instance.blobstores.blobstore },
            Config.root_domain,
            AgentBroadcaster.new,
            @dns_encoder,
            @logger
          )
          SetupStage.new(@base_job, @deployment_plan, vm_creator, local_dns_repo, dns_publisher)
        end
      end
    end
  end
end
