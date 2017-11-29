require 'securerandom'
require 'common/release/release_directory'
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

      def initialize(deployment_name, release_name, release_version, stemcell_os, stemcell_version, sha2, options = {})
        @deployment_name = deployment_name
        @release_name = release_name
        @release_version = release_version
        @stemcell_os = stemcell_os
        @stemcell_version = stemcell_version
        @sha2 = sha2
        @multi_digest = Digest::MultiDigest.new(logger)
        @jobs = options.fetch('jobs', [])
      end

      # @return [void]
      def perform
        logger.info("Exporting release: #{@release_name}/#{@release_version} for #{@stemcell_os}/#{@stemcell_version}")

        deployment_plan_stemcell = Bosh::Director::DeploymentPlan::Stemcell.parse({
          "os" => @stemcell_os,
          "version" => @stemcell_version
        })

        deployment_manager = Bosh::Director::Api::DeploymentManager.new
        targeted_deployment = deployment_manager.find_by_name(@deployment_name)

        release_manager = Bosh::Director::Api::ReleaseManager.new
        release = release_manager.find_by_name(@release_name)
        release_version_model = release_manager.find_version(release, @release_version)

        unless deployment_manifest_has_release?(targeted_deployment.manifest)
          raise ReleaseNotMatchingManifest, "Release version '#{@release_name}/#{@release_version}' not found in deployment '#{@deployment_name}' manifest"
        end

        planner_factory = DeploymentPlan::PlannerFactory.create(logger)
        planner = planner_factory.create_from_model(targeted_deployment)

        deployment_plan_stemcell.bind_model(planner.model)

        logger.info "Will compile with stemcell: #{deployment_plan_stemcell.desc}"

        release = planner.release(@release_name)

        export_release_job = create_compilation_instance_group(release_version_model, release, deployment_plan_stemcell)
        planner.add_instance_group(export_release_job)
        assembler = DeploymentPlan::Assembler.create(planner)
        assembler.bind_models({:should_bind_links => false, :should_bind_properties => false})

        lock_timeout = 15 * 60 # 15 minutes

        with_deployment_lock(@deployment_name, :timeout => lock_timeout) do
          compile_step(planner).perform

          tarball_state = create_tarball(release_version_model, deployment_plan_stemcell)
          task_result.write(tarball_state.to_json + "\n")
        end
        "Exported release: #{@release_name}/#{@release_version} for #{@stemcell_os}/#{@stemcell_version}"
      end

      private

      def compile_step(deployment_plan)
        DeploymentPlan::Stages::PackageCompileStage.create(deployment_plan)
      end

      def deployment_manifest_has_release?(manifest)
        deployment_manifest = YAML.load(manifest)
        deployment_manifest['releases'].each do |release|
          if (release['name'] == @release_name) && (release['version'].to_s == @release_version.to_s)
            return true
          end
        end
        false
      end

      def is_template_to_be_exported?(template)
        @jobs.empty? || @jobs.any? { |job| job['name'] == template.name }
      end

      def create_tarball(release_version_model, stemcell)
        blobstore_client = Bosh::Director::App.instance.blobstores.blobstore

        compiled_packages_group = CompiledPackageGroup.new(release_version_model, stemcell)
        templates = release_version_model.templates.select{|template| is_template_to_be_exported?(template)}

        compiled_release_downloader = CompiledReleaseDownloader.new(compiled_packages_group, templates, blobstore_client)
        download_dir = compiled_release_downloader.download

        manifest = CompiledReleaseManifest.new(compiled_packages_group, templates, stemcell)
        manifest.write(File.join(download_dir, 'release.MF'))

        output_path = File.join(download_dir, "compiled_release_#{Time.now.to_f}.tar.gz")
        archiver = Core::TarGzipper.new

        release_directory = Bosh::Common::Release::ReleaseDirectory.new(download_dir)
        archiver.compress(download_dir, release_directory.ordered_release_files, output_path)
        tarball_file = File.open(output_path, 'r')

        oid = blobstore_client.create(tarball_file)

        algorithm = @sha2 ? Digest::MultiDigest::SHA256 : Digest::MultiDigest::SHA1
        tarball_hexdigest = @multi_digest.create([algorithm], output_path)

        Bosh::Director::Models::Blob.new(
            blobstore_id: oid,
            sha1: tarball_hexdigest,
            type: 'exported-release',
        ).save

        {
          :blobstore_id => oid,
          :sha1 => tarball_hexdigest,
        }
      ensure
        compiled_release_downloader.cleanup unless compiled_release_downloader.nil?
      end

      def create_compilation_instance_group(release_version_model, release, deployment_plan_stemcell)
        instance_group = DeploymentPlan::InstanceGroup.new(logger)

        instance_group.name = 'dummy-job-for-compilation'
        instance_group.stemcell = deployment_plan_stemcell
        release_version_model.templates.map do |template|
          if is_template_to_be_exported?(template)
            instance_group.jobs << release.get_or_create_template(template.name)
          end
        end

        instance_group
      end
    end
  end
end
