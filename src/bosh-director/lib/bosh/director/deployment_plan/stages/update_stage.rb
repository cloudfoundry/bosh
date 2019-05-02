module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateStage
        def initialize(base_job, deployment_plan, multi_instance_group_updater, dns_encoder, link_provider_intents)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @multi_instance_group_updater = multi_instance_group_updater
          @dns_encoder = dns_encoder
          @link_provider_intents = link_provider_intents
        end

        def perform
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
          CleanupStemcellReferencesStage.new(@deployment_plan).perform
        end

        private

        def vm_creator
          return @vm_creator if @vm_creator

          template_blob_cache = @deployment_plan.template_blob_cache
          agent_broadcaster = AgentBroadcaster.new
          @vm_creator = Bosh::Director::VmCreator.new(
            @logger,
            template_blob_cache,
            @dns_encoder,
            agent_broadcaster,
            @link_provider_intents,
          )
        end

        def setup_stage
          local_dns_records_repo = LocalDnsRecordsRepo.new(@logger, Config.root_domain)
          local_dns_aliases_repo = LocalDnsAliasesRepo.new(@logger, Config.root_domain)
          dns_publisher = BlobstoreDnsPublisher.new(
            -> { App.instance.blobstores.blobstore },
            Config.root_domain,
            AgentBroadcaster.new,
            @logger,
          )

          SetupStage.new(
            base_job: @base_job,
            deployment_plan: @deployment_plan,
            vm_creator: vm_creator,
            local_dns_records_repo: local_dns_records_repo,
            local_dns_aliases_repo: local_dns_aliases_repo,
            dns_publisher: dns_publisher,
          )
        end
      end
    end
  end
end
