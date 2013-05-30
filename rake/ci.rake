namespace :ci do
  desc "Publish CI pipeline gems to S3"
  task :publish_pipeline_gems do
    cd(ENV['WORKSPACE']) do
      require_relative 'helpers/version_file'
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
    require_relative('helpers/micro_bosh_release')

    cd(ENV['WORKSPACE']) do
      release = Bosh::Helpers::MicroBoshRelease.new
      build_micro_bosh_release_value = release.build
      release_tarball = build_micro_bosh_release_value
      sh("s3cmd put #{release_tarball} #{s3_release_url(current_build_number)}")
    end
  end

  namespace :stemcell do
    desc "Build micro bosh stemcell from CI pipeline"
    task :micro, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        tarball_path = "release/bosh-#{candidate_build_number}.tgz"
        sh("s3cmd -f get #{s3_release_url(candidate_build_number)} #{tarball_path}")

        Rake::Task["stemcell:micro"].invoke(args[:infrastructure], tarball_path, candidate_build_number)
      end
      publish_stemcell(args[:infrastructure], 'micro')
    end

    desc "Build stemcell from CI pipeline"
    task :basic, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        Rake::Task["stemcell:basic"].invoke(args[:infrastructure], candidate_build_number)
      end
      publish_stemcell(args[:infrastructure], 'basic')
    end
  end

  namespace :system do
    namespace :vsphere do
      task :micro do
        cd(ENV['WORKSPACE']) do
          begin
            download_latest_stemcell('vsphere', 'micro')
            download_latest_stemcell('vsphere', 'basic')
            Rake::Task['spec:system:vsphere:micro'].invoke
          ensure
            rm_f(Dir.glob('*bosh-stemcell-*.tgz'))
          end
        end
      end
    end
  end



  def publish_stemcell(infrastructure, type)
    path = Dir.glob("/mnt/stemcells/#{infrastructure}-#{type}/work/work/*-stemcell-*-#{candidate_build_number}.tgz").first
    if path
      sh("s3cmd put #{path} #{s3_stemcell_base_url(infrastructure, type)}")
    end
  end

  def download_latest_stemcell(infrastructure, type)
    version_cmd = "s3cmd ls  #{s3_stemcell_base_url(infrastructure, type)} " +
                  "| sed -e 's/.*bosh-ci-pipeline.*stemcell-#{infrastructure}-\\(.*\\)\.tgz/\\1/' " +
                  "| sort -n | tail -1"
    version = %x[#{version_cmd}].chomp

    stemcell_filename = "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}-#{version}.tgz"
    latest_stemcell_url = s3_stemcell_base_url(infrastructure, type) + stemcell_filename
    sh("s3cmd -f get #{latest_stemcell_url}")
    ln_s("#{stemcell_filename}", "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}.tgz", force: true)
  end

  def current_build_number
    ENV['BUILD_NUMBER']
  end

  def candidate_build_number
    if ENV['CANDIDATE_BUILD_NUMBER'].to_s.empty?
      raise 'Please set the CANDIDATE_BUILD_NUMBER environment variable'
    end

    ENV['CANDIDATE_BUILD_NUMBER']
  end

  def s3_release_url(build_number)
    "s3://bosh-ci-pipeline/bosh-#{build_number}.tgz"
  end

  def s3_stemcell_base_url(infrastructure, type)
    "s3://bosh-ci-pipeline/stemcells/#{infrastructure}/#{type}/"
  end
end