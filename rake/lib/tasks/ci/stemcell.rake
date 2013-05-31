require_relative '../../helpers/do_not_add_to_me'

namespace :ci do
  namespace :stemcell do
    include Bosh::Helpers::DoNotAddToMe

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
end
