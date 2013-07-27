require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_environment'
      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('micro', args[:infrastructure])
      stemcell_environment.sanitize
      ENV['BUILD_PATH'] = stemcell_environment.build_path
      ENV['WORK_PATH'] = stemcell_environment.work_path
      ENV['STEMCELL_VERSION'] = stemcell_environment.stemcell_version

      tarball_path = "release/bosh-#{Bosh::Dev::Build.candidate.number}.tgz"

      sh("s3cmd -f get #{Bosh::Dev::Build.candidate.s3_release_url} #{tarball_path}")

      Rake::Task['stemcell:micro'].invoke(stemcell_environment.infrastructure, tarball_path, Bosh::Dev::Build.candidate.number)

      stemcell_environment.publish
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_environment'
      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('basic', args[:infrastructure])
      stemcell_environment.sanitize
      ENV['BUILD_PATH'] = stemcell_environment.build_path
      ENV['WORK_PATH'] = stemcell_environment.work_path
      ENV['STEMCELL_VERSION'] = stemcell_environment.stemcell_version

      Rake::Task['stemcell:basic'].invoke(stemcell_environment.infrastructure, Bosh::Dev::Build.candidate.number)

      stemcell_environment.publish
    end
  end
end
