require 'bosh/dev/build'
require 'bosh/dev/bulk_uploader'

namespace :ci do
  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/version_file'
    version_file = Bosh::Dev::VersionFile.new(Bosh::Dev::Build.candidate.number)
    version_file.write
    Rake::Task['all:finalize_release_directory'].invoke
    cd('pkg') do
      Bundler.with_clean_env do
        # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
        sh('gem', 'generate_index', '.')
      end
      Bosh::Dev::BulkUploader.new.upload_r('.', 'gems')
    end
  end

  desc 'Publish CI pipeline MicroBOSH release to S3'
  task :publish_microbosh_release => [:publish_pipeline_gems] do
    require 'bosh/dev/micro_bosh_release'

    release = Bosh::Dev::MicroBoshRelease.new
    Bosh::Dev::Build.candidate.upload(release)
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    Bosh::Dev::Build.candidate.
        promote_artifacts(access_key_id: ENV['AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'],
                          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT'])
  end
end
