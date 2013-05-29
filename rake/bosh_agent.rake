namespace :bosh_agent do
  task :update, [:vm, :gw_host, :gw_user] => :pre_stage_latest do |_, args|
    args.with_defaults(gw_user: 'vcap')

    vm = args[:vm]
    gateway_host = args[:gw_host]
    gateway_user = args[:gw_user]

    unless [vm, gateway_host, gateway_user].all?
      abort 'You must pass the VM target and the gateway host to this rake task.'
    end

    puts "VM: #{vm}"
    puts "Gateway host: #{gateway_host}"
    puts "Gateway user: #{gateway_user}"

    gem_path = Dir.glob('pkg/gems/bosh_agent*.gem').max_by { |f| File.mtime(f) }
    gem_file = File.basename(gem_path)

    puts "Local gem path: #{gem_path}"

    puts "Uploading gem"

    # remove file on remote

    sh "bosh scp #{vm} --upload --gateway_host #{gateway_host} --gateway_user #{gateway_user} #{gem_path} /tmp"

    run_on_vm_sudo(vm, gateway_user, gateway_host, '/var/vcap/bosh/bin/gem uninstall bosh_agent') # Use full gem path until this chore is
                                                                                                  # addressed: https://www.pivotaltracker.com/story/show/50760173

    run_on_vm_sudo(vm, gateway_user, gateway_host, "/var/vcap/bosh/bin/gem install /tmp/#{gem_file}")
    run_on_vm_sudo(vm, gateway_user, gateway_host, "sv restart agent")
    run_on_vm_sudo(vm, gateway_user, gateway_host, "rm /tmp/#{gem_file}")
  end

  def run_on_vm_sudo(vm, gw_user, gw_host, command)
    ip = `bosh vms | grep #{vm} | cut -d "|" -f 5 | cut -d "," -f 1`.strip

    sh <<-CMD
ssh -A #{gw_user}@#{gw_host} 'ssh #{gw_user}@#{ip} -o StrictHostKeyChecking=no "echo c1oudc0w | sudo -S #{command}"'
    CMD
  end
end
