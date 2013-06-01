require_relative '../../helpers/build'
require_relative '../../helpers/s3_stemcell'

namespace :ci do
  namespace :stemcell do
    desc "Build micro bosh stemcell from CI pipeline"
    task :micro, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        tarball_path = "release/bosh-#{Bosh::Helpers::Build.candidate.number}.tgz"
        sh("s3cmd -f get #{Bosh::Helpers::Build.candidate.s3_release_url} #{tarball_path}")

        Rake::Task["stemcell:micro"].invoke(args[:infrastructure], tarball_path, Bosh::Helpers::Build.candidate.number)
      end
      Bosh::Helpers::S3Stemcell.new(args[:infrastructure], 'micro').publish
    end

    desc "Build stemcell from CI pipeline"
    task :basic, [:infrastructure] do |t, args|
      cd(ENV['WORKSPACE']) do
        Rake::Task["stemcell:basic"].invoke(args[:infrastructure], Bosh::Helpers::Build.candidate.number)
      end
      Bosh::Helpers::S3Stemcell.new(args[:infrastructure], 'basic').publish
    end
  end
end
