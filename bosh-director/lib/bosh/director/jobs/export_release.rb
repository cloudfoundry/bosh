require 'securerandom'
require 'common/version/release_version'
require 'bosh/director/compiled_release_downloader'
require 'bosh/director/compiled_release_manifest'
require 'bosh/director/compiled_package_group'

module Bosh::Director
  module Jobs
    class ExportRelease < BaseJob
      include LockHelper

      @queue = :normal

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

        stemcell_manager = Bosh::Director::Api::StemcellManager.new
        @stemcell = stemcell_manager.find_by_os_and_version(@stemcell_os, @stemcell_version)

        logger.info "Will compile with stemcell: #{@stemcell.desc}"

        deployment_manager = Bosh::Director::Api::DeploymentManager.new
        @targeted_deployment = deployment_manager.find_by_name(@deployment_name)
        @deployment_manifest = Psych.load(@targeted_deployment.manifest)

        release_manager = Bosh::Director::Api::ReleaseManager.new
        release = release_manager.find_by_name(@release_name)
        @release_version_model = release_manager.find_version(release, @release_version)

        unless deployment_manifest_has_release?
          raise ReleaseNotMatchingManifest, "Release version `#{@release_name}/#{@release_version}' not found in deployment `#{@deployment_name}' manifest"
        end

        validate_release_packages

        lock_timeout = 15 * 60 # 15 minutes

        with_deployment_lock(@deployment_name, :timeout => lock_timeout) do
          with_release_lock(@release_name, :timeout => lock_timeout) do
            with_stemcell_lock(@stemcell.name, @stemcell.version, :timeout => lock_timeout) do

              planner = create_planner(stemcell_manager)
              package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
                  planner,
                  Config.cloud, # CPI
                  Config.logger,
                  Config.event_log,
                  self
              )
              package_compile_step.perform

              tarball_state = create_tarball
              result_file.write(tarball_state.to_json + "\n")

            end
          end
        end
        "Exported release: #{@release_name}/#{@release_version} for #{@stemcell_os}/#{@stemcell_version}"
      end

      private

      def deployment_manifest_has_release?
        @deployment_manifest["releases"].each do |release|
          if (release["name"] == @release_name) && (release["version"].to_s == @release_version.to_s)
            return true
          end
        end
        false
      end

      def create_planner(stemcell_manager)
        cloud_config_model = @targeted_deployment.cloud_config

        planner_factory = DeploymentPlan::PlannerFactory.create(Config.event_log, Config.logger)
        planner = planner_factory.planner_without_vm_binding(
            @deployment_manifest,
            cloud_config_model,
            {}
        )
        network_name = planner.networks.first.name

        fake_resource_pool_manifest = {
            "name" => "just_for_compiling",
            "network" => network_name,
            "stemcell" => { "name" => @stemcell.name, "version" => @stemcell.version }
        }

        resource_pool = DeploymentPlan::ResourcePool.new(planner, fake_resource_pool_manifest, Config.logger)
        planner.add_resource_pool(resource_pool)
        planner.reset_jobs

        fake_job = create_fake_job(planner, fake_resource_pool_manifest, network_name)
        planner.add_job(fake_job)

        assembler = DeploymentPlan::Assembler.new(
            planner,
            stemcell_manager,
            Config.cloud,
            nil, # blobstore not used for this assembler purposes
            @logger,
            @event_log
        )
        @logger.info('Created deployment plan')

        track_and_log('Binding existing deployment') do
          assembler.bind_existing_deployment
        end

        track_and_log('Binding resource pools') do
          assembler.bind_resource_pools
        end

        planner
      end

      def create_tarball

        blobstore_client = Bosh::Director::App.instance.blobstores.blobstore

        compiled_packages_group = CompiledPackageGroup.new(@release_version_model, @stemcell)
        templates = @release_version_model.templates.map

        compiled_release_downloader = CompiledReleaseDownloader.new(compiled_packages_group, templates, blobstore_client)
        download_dir = compiled_release_downloader.download

        manifest = CompiledReleaseManifest.new(compiled_packages_group, templates, @stemcell)
        manifest.write(File.join(download_dir, 'release.MF'))

        output_path = File.join(download_dir, "compiled_release_#{Time.now.to_f}.tar.gz")
        archiver = Core::TarGzipper.new

        archiver.compress(download_dir, ['compiled_packages', 'jobs', 'release.MF'], output_path)
        tarball_file = File.open(output_path, 'r')

        oid = blobstore_client.create(tarball_file)

        {
            :blobstore_id => oid,
            :sha1 => Digest::SHA1.file(output_path).hexdigest,
        }
      ensure
        compiled_release_downloader.cleanup unless compiled_release_downloader.nil?
      end

      def create_fake_job(planner, fake_resource_pool_manifest, network_name)
        fake_job_spec_for_compiling = {
            "name" => "dummy-job-for-compilation",
            "release" => @release_name,
            "instances" => 1,
            "resource_pool" => fake_resource_pool_manifest['name'],
            "templates" => @release_version_model.templates.map do |template|
              { "name" => template.name, "release" => @release_name }
            end,
            "networks" => [ "name" => network_name ],
        }

        fake_job = DeploymentPlan::Job.parse(planner, fake_job_spec_for_compiling, Config.event_log, Config.logger)
        @release_version_model.packages.each { |package| fake_job.packages[package.name] = package }
        fake_job.resource_pool.stemcell.bind_model
        fake_job.release.bind_model
        fake_job.templates.each { |template| template.bind_models }
        fake_job
      end

      def validate_release_packages
        faults = Set.new
        @release_version_model.packages.each do |package|
          packages_list = @release_version_model.transitive_dependencies(package)
          packages_list << package

          packages_list.each { |needed_package|
            if needed_package.sha1.nil? || needed_package.blobstore_id.nil?
              compiled_packages_list = Bosh::Director::Models::CompiledPackage[:package_id => needed_package.id, :stemcell_id => @stemcell.id]
              if compiled_packages_list.nil?
                faults << needed_package
              end
            end
          }
        end

        unless faults.empty?
          sorted_faults = faults.to_a.sort_by { |p| p.name }
          msg = "Can't export release `#{@release_name}/#{@release_version}'. It references packages without" +
              " source code that are not compiled against `#{@stemcell.desc}':\n"
          sorted_faults.each do |non_compiled_package|
            msg += " - #{non_compiled_package.name}/#{non_compiled_package.version}\n"
          end
          raise PackageMissingSourceCode, msg
        end
      end

    end
  end
end
