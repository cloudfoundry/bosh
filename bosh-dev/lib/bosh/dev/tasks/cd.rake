namespace :cd do
  desc 'Redeploy full BOSH'
  task :deploy, [
    :infrastructure_name,
    :build_number,
    :micro_target,
    :bosh_target,
    :environment_name,
    :deployment_name,
  ] do |_, args|
    require 'bosh/dev/automated_deployer'
    deployer = Bosh::Dev::AutomatedDeployer.for_rake_args(args)
    deployer.deploy
  end
end
