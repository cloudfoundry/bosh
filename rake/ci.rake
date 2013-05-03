namespace :ci do
  desc "Publish CI pipeline gems to S3"
  task :publish_pipeline_gems do
    cd(ENV['WORKSPACE']) do
      file_contents = File.read("BOSH_VERSION")
      file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{build_number}")
      File.open("BOSH_VERSION", 'w') { |f| f.write file_contents }
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
    release_tarball = build_micro_bosh_release
    sh("s3cmd put #{release_tarball} #{s3_release_url}")
  end

  desc "Build micro bosh stemcell from CI pipeline"
  task :micro, [:infrastructure] do |t, args|
    tarball_path = "release/micro-bosh-#{build_number}.tgz"

    sh("s3cmd -f get #{s3_release_url} #{tarball_path}")
    Rake::Task["stemcell:micro"].invoke(args[:infrastructure], tarball_path)
  end

  def build_number
    ENV['BUILD_NUMBER']
  end

  def s3_release_url
    "s3://bosh-ci-pipeline/micro-bosh-#{build_number}.tgz"
  end
end