namespace :local do
  desc 'build a Stemcell locally'
  task :build_stemcell, [:infrastructure_name, :operating_system_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/micro_bosh_release'
    require 'bosh/dev/stemcell_builder'

    build = Bosh::Dev::Build.candidate
    release_tarball_path = Bosh::Dev::MicroBoshRelease.new.tarball

    Bosh::Stemcell::BuilderCommand.new(
        ENV,
        infrastructure_name:   args[:infrastructure_name],
        operating_system_name: args[:operating_system_name],
        version:               ENV['CANDIDATE_BUILD_NUMBER'],
        release_tarball_path:  release_tarball_path,
      ).build

  end
end
