namespace :cd do
  desc 'Redeploy full BOSH'
  task :full_bosh_deploy, [
    :build_number,
    :infrastructure_name,
    :operating_system_name,
    :bosh_target,
    :environment_name,
    :deployment_name,
  ] do |_, args|
    require 'bosh/dev/automated_deploy'
    deployer = Bosh::Dev::AutomatedDeploy.for_rake_args(args)
    deployer.deploy
  end
end
