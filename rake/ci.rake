namespace :ci do
  desc "Publish CI pipeline gems to S3"
  task :publish_pipeline_gems do
    cd(ENV['WORKSPACE']) do
      update_bosh_version(current_build_number)
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
    cd(ENV['WORKSPACE']) do
      release_tarball = build_micro_bosh_release
      sh("s3cmd put #{release_tarball} #{s3_release_url(current_build_number)}")
    end
  end

  namespace :stemcell do
    desc "Build micro bosh stemcell from CI pipeline"
    task :micro, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        tarball_path = "release/micro-bosh-#{candidate_build_number}.tgz"
        sh("s3cmd -f get #{s3_release_url(candidate_build_number)} #{tarball_path}")

        Rake::Task["stemcell:micro"].invoke(args[:infrastructure], tarball_path, candidate_build_number)
      end
    end

    desc "Build stemcell from CI pipeline"
    task :basic, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        Rake::Task["stemcell:basic"].invoke(args[:infrastructure], candidate_build_number)
      end
    end
  end

  def current_build_number
    ENV['BUILD_NUMBER']
  end

  def candidate_build_number
    ENV['CANDIDATE_BUILD_NUMBER']
  end

  def s3_release_url(build_number)
    "s3://bosh-ci-pipeline/micro-bosh-#{build_number}.tgz"
  end
end