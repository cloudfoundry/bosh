namespace :ci do
  namespace :run do
    desc 'Meta task to run spec:unit and rubocop'
    task unit: %w(spec:unit)

    desc 'Meta task to run spec:integration'
    task integration: %w(spec:integration)
  end

  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/gems_generator'

    Bosh::Dev::GemsGenerator.new.generate_and_upload
  end

  desc 'Publish CI pipeline MicroBOSH release to S3'
  task publish_microbosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/micro_bosh_release'

    build = Bosh::Dev::Build.candidate
    build.upload(Bosh::Dev::MicroBoshRelease.new)
  end

  desc 'Publish CI pipeline stemcell to S3'
  task :publish_stemcell, [:stemcell_type, :infrastructure] do |_, args|
    require 'bosh/dev/stemcell_builder'
    require 'bosh/dev/stemcell_publisher'

    options = args.to_hash

    stemcell_builder = Bosh::Dev::StemcellBuilder.new(options.fetch(:stemcell_type), options.fetch(:infrastructure))
    publisher = Bosh::Dev::StemcellPublisher.new
    publisher.publish(stemcell_builder.build)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'

    build = Bosh::Dev::Build.candidate
    build.promote_artifacts(
      access_key_id: ENV['AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT']
    )
  end
end
