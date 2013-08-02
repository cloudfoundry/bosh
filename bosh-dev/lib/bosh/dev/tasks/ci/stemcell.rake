require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/stemcell/stemcell'

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

      bosh_release_path = Bosh::Dev::Build.candidate.download_release
      Rake::Task['stemcell:micro'].invoke(bosh_release_path, stemcell_environment.infrastructure, Bosh::Dev::Build.candidate.number)

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
