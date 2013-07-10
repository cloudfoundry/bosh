require 'jenkins_api_client'

task :build_check do
  %w(BOSH_CI_JOB BOSH_CI_SERVER).each do |v|
    fail("Please set #{v}") unless ENV[v]
  end

  client = JenkinsApi::Client.new(server_ip: ENV['BOSH_CI_SERVER'])
  color = client.job.list_details(ENV['BOSH_CI_JOB'])['color']

  if color.start_with? 'red'
    fail 'The build is red'
  else
    puts "The build is #{color}"
  end
end
