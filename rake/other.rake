require "cli/version"

desc "Pulls the most recent code, run all the tests and pushes the repo"
task :shipit do
  %x[git pull --rebase origin master]
  abort "Failed to pull, aborting." if $?.exitstatus > 0

  Rake::Task[:default].invoke

  %x[git push origin master]
  abort "Failed to push, aborting." if $?.exitstatus > 0
end

namespace :agent do
  desc "Build a .deb package of the checked out agent/"
  file "bosh-agent_1.0_amd64.deb" => FileList["bosh_agent/**/*"] do
    puts "Building .deb package..."
    sh "bundle exec fpm -f -s dir -t deb -n bosh_agent --prefix /var/vcap/bosh/lib/ruby/gems/1.9.1/gems/bosh_agent-#{Bosh::Cli::VERSION}/ -C bosh_agent ."
  end

  desc "Upload the .deb for the checked out agent code to the server"
  task :upload, [:vm, :gw_host, :gw_user] => ["bosh-agent_1.0_amd64.deb"] do |_, args|
    args.with_defaults(gw_user: "vcap")

    vm = args[:vm]
    gateway_host = args[:gw_host]
    gateway_user = args[:gw_user]

    unless [vm, gateway_host, gateway_user].all?
      abort "You must pass the VM target and the gateway host to this rake task."
    end

    puts "Uploading .deb package..."
    sh "bosh scp #{vm} --upload --gateway_host #{gateway_host} --gateway_user #{gateway_user} bosh-agent_1.0_amd64.deb /tmp"

    puts "Restarting the agent..."
    ip = `bosh vms | grep #{vm} | cut -d "|" -f 5 | cut -d "," -f 1`.strip
    sh <<-CMD
      ssh -A #{gateway_user}@#{gateway_host} 'ssh #{gateway_user}@#{ip} -o StrictHostKeyChecking=no "echo c1oudc0w | sudo -S sv restart agent"'
    CMD
  end
end
