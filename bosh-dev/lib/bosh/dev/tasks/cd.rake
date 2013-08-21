namespace :cd do
  desc 'Automate deploying a built Bosh to '
  task :deploy, [:build_number, :micro_target, :bosh_target, :environment] do |_, args|
    require 'bosh/dev/automated_deployer'

    deployer = Bosh::Dev::AutomatedDeployer.new(
        micro_target: args[:micro_target],
        bosh_target: args[:bosh_target],
        build_number: args[:build_number],
        environment: args[:environment]
    )
    deployer.deploy
  end
end
