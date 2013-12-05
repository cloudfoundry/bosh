namespace :local do
  desc 'build a Stemcell locally'
  task :build_stemcell, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_cli_session'
    require 'bosh/dev/stemcell_builder'

    build = Bosh::Dev::Build.candidate
    bosh_cli_session = Bosh::Dev::BoshCliSession.new
    release_tarball_path =
      Dir.chdir('release') do
        output = bosh_cli_session.run_bosh('create release --force --with-tarball')
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end

    Bosh::Stemcell::BuilderCommand.new(
        ENV,
        infrastructure_name:   args[:infrastructure_name],
        operating_system_name: args[:operating_system_name],
        agent_name:            args[:agent_name],
        version:               ENV['CANDIDATE_BUILD_NUMBER'],
        release_tarball_path:  release_tarball_path,
      ).build

  end
end
