namespace :ci do
  desc "Publish the code coverage report"
  task :publish_coverage_report do
    require 'codeclimate-test-reporter'
    SimpleCov.formatter = CodeClimate::TestReporter::Formatter
    SimpleCov::ResultMerger.merged_result.format!
  end

  task :verify_promoted_in_candidate, [:candidate_sha] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/git_branch_merger'
    merger = Bosh::Dev::GitBranchMerger.build
    candidate_sha = args.to_hash.fetch(:candidate_sha)

    if merger.sha_does_not_include_latest_master?(candidate_sha)
      fail "Candidate #{candidate_sha} does not contain latest master"
    end unless ENV['SKIP_SHA_VERIFICATION'] == 'true'
  end

  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/build'
    require 'bosh/dev/gems_generator'
    build = Bosh::Dev::Build.candidate
    gems_generator = Bosh::Dev::GemsGenerator.new(build)
    gems_generator.generate_and_upload
  end

  desc 'Publish CI pipeline BOSH release to S3'
  task :publish_bosh_release, [:candidate_sha] => [:verify_promoted_in_candidate, :publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_release_publisher'
    build = Bosh::Dev::Build.candidate
    Bosh::Dev::BoshReleasePublisher.setup_for(build).publish
  end

  desc 'Publish the given stemcell to S3 to bucket :publish_bucket'
  task :publish_stemcell, [:stemcell_path, :s3_bucket_name] do |_, args|
    require 'bosh/dev/stemcell_publisher'

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build args.s3_bucket_name
    stemcell_publisher.publish(args.stemcell_path)
  end

  desc 'Build a stemcell for the given :infrastructure, :hypervisor_name, :operating_system, :agent_name, :s3 bucket_name, and :s3 os image key on a stemcell building vm and publish to S3 to :publish_s3_bucket_name'
  task :publish_stemcell_in_vm, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :vm_name, :agent_name, :os_image_s3_bucket_name, :os_image_s3_key, :publish_s3_bucket_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_vm'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/build_environment'
    require 'bosh/dev/vm_command/build_and_publish_stemcell_command'

    definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, false)
    environment = Bosh::Stemcell::BuildEnvironment.new(ENV.to_hash, definition, Bosh::Dev::Build.candidate.number, nil, nil)

    stemcell_vm = Bosh::Dev::StemcellVm.new(args.vm_name)
    command = Bosh::Dev::VmCommand::BuildAndPublishStemcellCommand.new(environment, ENV, args.to_hash)
    stemcell_vm.run(command)
  end

  desc 'Build and publish an OS image on a stemcell building VM'
  task :publish_os_image_in_vm, [:operating_system_name, :operating_system_version, :vm_name, :os_image_s3_bucket_name, :os_image_s3_key] do |_, args|
    require 'bosh/dev/stemcell_vm'
    require 'bosh/dev/vm_command/build_and_publish_os_image_command'

    stemcell_vm = Bosh::Dev::StemcellVm.new(args.vm_name)
    command = Bosh::Dev::VmCommand::BuildAndPublishOsImageCommand.new(ENV, args.to_hash)
    stemcell_vm.run(command)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end

  desc 'Promote candidate sha to stable branch outside of the promote_artifacts task'
  task :promote, [:candidate_build_number, :candidate_sha, :feature_branch, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/promoter'
    promoter = Bosh::Dev::Promoter.build(args.to_hash)
    promoter.promote
  end
end
