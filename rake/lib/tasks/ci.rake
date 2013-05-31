require_relative '../helpers/do_not_add_to_me'

namespace :ci do
  include Bosh::Helpers::DoNotAddToMe

  desc "Publish CI pipeline gems to S3"
  task :publish_pipeline_gems do
    cd(ENV['WORKSPACE']) do
      require_relative '../helpers/version_file'
      version_file = Bosh::Helpers::VersionFile.new(current_build_number)
      version_file.write
      Rake::Task["all:finalize_release_directory"].invoke
      Bundler.with_clean_env do
        # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
        sh("cd pkg && gem generate_index .")
      end
      sh("cd pkg && s3cmd sync . s3://bosh-ci-pipeline/gems/")
    end
  end

  desc "Publish CI pipeline MicroBOSH release to S3"
  task :publish_microbosh_release => [:publish_pipeline_gems] do
    require_relative('../helpers/micro_bosh_release')

    cd(ENV['WORKSPACE']) do
      release = Bosh::Helpers::MicroBoshRelease.new
      build_micro_bosh_release_value = release.build
      release_tarball = build_micro_bosh_release_value
      sh("s3cmd put #{release_tarball} #{s3_release_url(current_build_number)}")
    end
  end
end
