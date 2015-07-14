require 'securerandom'
require 'common/version/release_version'
require 'pp'

module Bosh::Director
  module Jobs
    class ExportRelease < BaseJob
      include LockHelper

      @queue = :normal

      @stemcell
      @targeted_deployment
      @release_version

      def self.job_type
        :export_release
      end

      def initialize(deployment_name, release_name, release_version, stemcell_os, stemcell_version, options = {})
        @deployment_name = deployment_name
        @release_name = release_name
        @release_version = release_version
        @stemcell_os = stemcell_os
        @stemcell_version = stemcell_version
      end

      # @return [void]
      def perform
        logger.info("Exporting release: #{@release_name}/#{@release_version} for #{@stemcell_os}/#{@stemcell_version}")
        validate_and_prepare
        lock_timeout = 15 * 60 # 15 minutes

        with_deployment_lock(@deployment_name, :timeout => lock_timeout) do
          with_release_lock(@release_name, :timeout => lock_timeout) do
            with_stemcell_lock(@stemcell.name, @stemcell.version, :timeout => lock_timeout) do

              planner = create_planner
              package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
                  planner,
                  Config.cloud, # CPI
                  Config.logger,
                  Config.event_log,
                  self
              )
              package_compile_step.perform
            end
          end
        end
      end

      def validate_and_prepare
        stemcell_manager = Bosh::Director::Api::StemcellManager.new
        @stemcell = stemcell_manager.find_by_os_and_version(@stemcell_os, @stemcell_version)

        logger.info "Will compile with stemcell: #{@stemcell.desc}"

        deployment_manager = Bosh::Director::Api::DeploymentManager.new
        @targeted_deployment = deployment_manager.find_by_name(@deployment_name)

        release_manager = Bosh::Director::Api::ReleaseManager.new
        release = release_manager.find_by_name(@release_name)
        @release_version = release_manager.find_version(release, @release_version)
      end

      def create_planner
        modified_deployment_manifest = Psych.load(@targeted_deployment.manifest)
        cloud_config_model = @targeted_deployment.cloud_config
        network_name = cloud_config_model.manifest['networks'][0]['name']

        fake_resource_pool_manifest = {
            "name" => "just_for_compiling",
            "network" => network_name,
            "stemcell" => { "name" => @stemcell.name, "version" => @stemcell.version }
        }

        planner_factory = DeploymentPlan::PlannerFactory.create(Config.event_log, Config.logger)
        planner = planner_factory.planner_without_vm_binding(
            modified_deployment_manifest,
            cloud_config_model,
            {}
        )

        resource_pool = DeploymentPlan::ResourcePool.new(planner, fake_resource_pool_manifest, Config.logger)
        planner.add_resource_pool(resource_pool)
        planner.reset_jobs

        fake_job = create_fake_job(planner, fake_resource_pool_manifest, network_name)
        planner.add_job(fake_job)

        planner
      end

      def create_fake_job(planner, fake_resource_pool_manifest, network_name)
        fake_job_spec_for_compiling = {
            "name" => "dummy-job-for-compilation",
            "release" => @release_name,
            "instances" => 1,
            "resource_pool" => fake_resource_pool_manifest['name'],
            "templates" => @release_version.templates.map do |template|
              { "name" => template.name, "release" => @release_name }
            end,
            "networks" => [ "name" => network_name ],
        }

        fake_job = DeploymentPlan::Job.parse(planner, fake_job_spec_for_compiling, Config.event_log, Config.logger)
        @release_version.packages.each { |package| fake_job.packages[package.name] = package }
        fake_job.resource_pool.stemcell.bind_model
        fake_job.release.bind_model
        fake_job.templates.each { |template| template.bind_models }
        fake_job
      end

    end
  end
end
