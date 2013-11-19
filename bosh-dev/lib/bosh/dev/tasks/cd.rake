namespace :cd do
  desc 'Redeploy full BOSH'
  task :deploy, [
    :build_number,
    :infrastructure_name,
    :operating_system_name,
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
