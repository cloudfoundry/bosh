namespace :ci do
  namespace :run do
    desc 'Meta task to run spec:unit and rubocop'
    task unit: %w(spec:unit)

    desc 'Meta task to run spec:integration'
    task integration: %w(spec:integration)
  end

  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/build'
    require 'bosh/dev/gems_generator'
    build = Bosh::Dev::Build.candidate
    gems_generator = Bosh::Dev::GemsGenerator.new(build)
    gems_generator.generate_and_upload
  end

  desc 'Publish CI pipeline MicroBOSH release to S3'
  task publish_microbosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_release'
    build = Bosh::Dev::Build.candidate
    build.upload_release(Bosh::Dev::BoshRelease.new)
  end

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and copy to ./tmp/'
  task :build_stemcell, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_builder'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name, args.agent_name)
    stemcell_file = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_file, File.join('tmp', File.basename(stemcell_file)))
  end

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and publish to S3'
  task :publish_stemcell, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_builder'
    require 'bosh/dev/stemcell_publisher'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name, args.agent_name)
    stemcell_file = stemcell_builder.build_stemcell

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build
    stemcell_publisher.publish(stemcell_file)
  end

  task :publish_stemcell_in_vm, [:infrastructure_name, :operating_system_name, :vm_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_vm'
    stemcell_vm = Bosh::Dev::StemcellVm.new(args.to_hash, ENV)
    stemcell_vm.publish
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end

  task :promote, [:candidate_build_number, :candidate_sha, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/promoter'

    logger = Logger.new(STDERR)

    promoter = Bosh::Dev::Promoter.new(args.to_hash.merge(logger: logger))
    promoter.promote
  end
end
