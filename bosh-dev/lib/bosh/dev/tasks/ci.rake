namespace :ci do
  desc "Publish the code coverage report"
  task :publish_coverage_report do
    require 'codeclimate-test-reporter'
    SimpleCov.formatter = CodeClimate::TestReporter::Formatter
    SimpleCov::ResultMerger.merged_result.format!
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
  task publish_bosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_release_publisher'
    build = Bosh::Dev::Build.candidate
    Bosh::Dev::BoshReleasePublisher.setup_for(build).publish
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system, and :agent_name and publish to S3'
  task :publish_stemcell, [:stemcell_path] do |_, args|
    require 'bosh/dev/stemcell_publisher'

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build
    stemcell_publisher.publish(args.stemcell_path)
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system, :agent_name, :s3 bucket_name, and :s3 os image key on a stemcell building vm and publish to S3'
  task :publish_stemcell_in_vm, [:infrastructure_name, :operating_system_name, :operating_system_version, :vm_name, :agent_name, :os_image_s3_bucket_name, :os_image_s3_key] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_vm'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/build_environment'

    definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.operating_system_name, args.operating_system_version, args.agent_name)
    environment = Bosh::Stemcell::BuildEnvironment.new(ENV.to_hash, definition, Bosh::Dev::Build.candidate.number, nil, nil)

    stemcell_vm = Bosh::Dev::StemcellVm.new(args.to_hash, ENV, environment)
    stemcell_vm.publish
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end

  desc 'Promote candidate sha to stable branch outside of the promote_artifacts task'
  task :promote, [:candidate_build_number, :candidate_sha, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/promoter'
    promoter = Bosh::Dev::Promoter.build(args.to_hash)
    promoter.promote
  end
end
