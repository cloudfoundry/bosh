namespace :ci do
  namespace :run do
    desc 'Meta task to run spec:unit and rubocop'
    task unit: %w(rubocop spec:unit)

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

    Bosh::Dev::Build.candidate.upload(Bosh::Dev::MicroBoshRelease.new)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'

    Bosh::Dev::Build.candidate.
        promote_artifacts(access_key_id: ENV['AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'],
                          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT'])
  end
end
