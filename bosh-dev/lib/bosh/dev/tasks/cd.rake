namespace :cd do
  desc 'Automate deploying a built Bosh to '
  task :deploy, [:build_number, :micro_target, :bosh_target, :environment] do |_, args|
    require 'bosh/dev/automated_deployer'

    deployer = Bosh::Dev::AutomatedDeployer.for_environment(
      args.micro_target,
      args.bosh_target,
      args.build_number,
      args.environment,
    )
    deployer.deploy
  end
end
