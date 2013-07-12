require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        tarball_path = "release/bosh-#{Bosh::Dev::Build.candidate.number}.tgz"
        sh("s3cmd -f get #{Bosh::Dev::Build.candidate.s3_release_url} #{tarball_path}")

        Rake::Task['stemcell:micro'].invoke(args[:infrastructure], tarball_path, Bosh::Dev::Build.candidate.number)
      end
      publish_stemcell(args[:infrastructure], 'micro')
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        Rake::Task['stemcell:basic'].invoke(args[:infrastructure], Bosh::Dev::Build.candidate.number)
      end
      publish_stemcell(args[:infrastructure], 'basic')
    end
  end

  def publish_stemcell(infrastructure, type)
    stemcell = Bosh::Dev::Stemcell.from_jenkins_build(infrastructure, type, Bosh::Dev::Build.candidate)
    Bosh::Dev::Pipeline.new.publish_stemcell(stemcell)
  end
end
