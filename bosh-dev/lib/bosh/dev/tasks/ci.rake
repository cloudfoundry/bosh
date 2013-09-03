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

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and copy to ./tmp/'
  task :build_stemcell, [:infrastructure, :operating_system] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_builder'

    options = args.to_hash

    stemcell_builder = Bosh::Dev::StemcellBuilder.new(Bosh::Dev::Build.candidate,
                                                      options.fetch(:infrastructure),
                                                      options.fetch(:operating_system))
    stemcell_file = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_file, File.join('tmp', File.basename(stemcell_file)))
  end

  desc 'Build a stemcell for the given :infrastructure, and :operating_system and publish to S3'
  task :publish_stemcell, [:infrastructure, :operating_system] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_builder'
    require 'bosh/dev/stemcell_publisher'

    options = args.to_hash

    stemcell_builder = Bosh::Dev::StemcellBuilder.new(Bosh::Dev::Build.candidate,
                                                      options.fetch(:infrastructure),
                                                      options.fetch(:operating_system))
    stemcell_file = stemcell_builder.build_stemcell

    stemcell_publisher = Bosh::Dev::StemcellPublisher.new
    stemcell_publisher.publish(stemcell_file)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'

    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end
end
