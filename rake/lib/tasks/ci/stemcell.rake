require_relative '../../helpers/build'
require_relative '../../helpers/pipeline'
require_relative '../../helpers/stemcell'

namespace :ci do
  namespace :stemcell do
    desc "Build micro bosh stemcell from CI pipeline"
    task :micro, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        tarball_path = "release/bosh-#{Bosh::Helpers::Build.candidate.number}.tgz"
        sh("s3cmd -f get #{Bosh::Helpers::Build.candidate.s3_release_url} #{tarball_path}")

        Rake::Task["stemcell:micro"].invoke(args[:infrastructure], tarball_path, Bosh::Helpers::Build.candidate.number)
      end
      publish_stemcell(args[:infrastructure], 'micro')
    end

    desc "Build stemcell from CI pipeline"
    task :basic, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        Rake::Task["stemcell:basic"].invoke(args[:infrastructure], Bosh::Helpers::Build.candidate.number)
      end
      publish_stemcell(args[:infrastructure], 'basic')
    end
  end

  def publish_stemcell(infrastructure, type)
    stemcell = Bosh::Helpers::Stemcell.from_jenkins_build(infrastructure, type, Bosh::Helpers::Build.candidate)
    Bosh::Helpers::Pipeline.new.publish_stemcell(stemcell)
  end
end
