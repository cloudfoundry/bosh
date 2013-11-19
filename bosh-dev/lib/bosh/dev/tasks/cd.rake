namespace :cd do
  desc 'Automate deploying a built Bosh to '
  task :deploy, [:build_number, :micro_target, :bosh_target, :environment] do |_, args|
    require 'bosh/dev/aws/automated_deploy_builder'

    deployer = Bosh::Dev::Aws::AutomatedDeployBuilder.new.build(
      args.micro_target,
      args.bosh_target,
      args.build_number,
      args.environment,
    )
    deployer.migrate
    deployer.deploy
  end
end
