require 'jenkins_api_client'

task :build_check, [:server, :job_name] do |_, args|
  require 'bosh/dev/build_check'

  args.with_defaults(
      server: 'bosh-jenkins.cf-app.com',
      job_name: 'bosh_build_flow'
  )

  jenkins_client = JenkinsApi::Client.new(server_ip: args.server)
  if Bosh::Dev::BuildCheck.new(jenkins_client, args.job_name).failing?
    fail 'The build is red!'
  else
    puts 'The build is green. Shipping.'
  end
end
