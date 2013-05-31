namespace :bosh_agent do
  task :update, [:instance_name, :gw_host, :gw_user] => :pre_stage_latest do |_, args|
    require_relative '../helpers/instance'

    options = args.with_defaults(gw_user: 'vcap')
    instance = Bosh::Helpers::Instance.new(options)

    local_gem_path = Dir.glob('pkg/gems/bosh_agent*.gem').max_by { |f| File.mtime(f) }
    remote_gem_path = File.join('/tmp', File.basename(local_gem_path))

    puts "Uploading #{local_gem_path} (local) to #{remote_gem_path} (remote)"
    sh "bosh scp #{instance.name} --upload --gateway_host #{instance.gw_host} --gateway_user #{instance.gw_user} #{local_gem_path} #{remote_gem_path}"

    instance.run('/var/vcap/bosh/bin/gem uninstall bosh_agent') # Use full gem path until this chore is
                                                               # addressed: https://www.pivotaltracker.com/story/show/50760173

    instance.run("/var/vcap/bosh/bin/gem install #{remote_gem_path}")
    instance.run('sv restart agent')
    instance.run("rm #{remote_gem_path}")
  end
end
