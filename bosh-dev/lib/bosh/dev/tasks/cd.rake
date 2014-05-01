namespace :cd do
  desc 'Deploy or update Micro BOSH'
  task :micro_bosh_deploy, [
    :build_number,
    :infrastructure_name,
    :operating_system_name,
    :operating_system_version,
    :agent_name,
    :environment_name,
    :deployment_name,
  ] do |_, args|
    require 'bosh/dev/automated_deploy'
    deployer = Bosh::Dev::AutomatedDeploy.for_rake_args(args)
    deployer.deploy_micro
  end

  desc 'Deploy or update full BOSH'
  task :full_bosh_deploy, [
    :build_number,
    :infrastructure_name,
    :operating_system_name,
    :operating_system_version,
    :agent_name,
    :bosh_target,
    :environment_name,
    :deployment_name,
  ] do |_, args|
    require 'bosh/dev/automated_deploy'
    deployer = Bosh::Dev::AutomatedDeploy.for_rake_args(args)
    deployer.deploy(args.bosh_target)
  end
end
