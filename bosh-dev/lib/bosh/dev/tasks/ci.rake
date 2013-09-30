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
    Bosh::Dev::GemsGenerator.new(build).generate_and_upload
  end
  
  desc 'Build gems without publishing'
  task :build_pipeline_gems do
    require 'bosh/dev/gems_generator'

    Bosh::Dev::GemsGenerator.new.generate
  end    

  desc 'Publish CI pipeline MicroBOSH release to S3'
  task publish_microbosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/micro_bosh_release'
    Bosh::Dev::Build.candidate.upload_release(Bosh::Dev::MicroBoshRelease.new)
  end

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and copy to ./tmp/'
  task :build_stemcell, [:infrastructure_name, :operating_system_name] do |_, args|
    require 'bosh/dev/stemcell_builder'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name)
    stemcell_file = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_file, File.join('tmp', File.basename(stemcell_file)))
  end

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and publish to S3'
  task :publish_stemcell, [:infrastructure_name, :operating_system_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_builder'
    require 'bosh/dev/stemcell_publisher'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name)
    stemcell_file = stemcell_builder.build_stemcell

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build
    stemcell_publisher.publish(stemcell_file)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    Bosh::Dev::Build.candidate.promote_artifacts
  end
end
