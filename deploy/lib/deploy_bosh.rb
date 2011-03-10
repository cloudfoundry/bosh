require "expect"
require "pp"
require "pty"
require "set"
require "stringio"
require "yaml"
require "thor"

require "net/ssh"
require "net/scp"
require "net/ssh/gateway"
require "yajl"

module DeployBosh
   class Deploy < Thor
     include Thor::Actions

     BASE_PATH = Dir.pwd
     COOKBOOKS_PATH = File.join(BASE_PATH, "cookbooks");
     SSH_WRAPPER = File.join(File.expand_path("../../bin", __FILE__), "ssh_wrapper.sh")
     ENV['GIT_SSH'] = SSH_WRAPPER

     no_tasks do
       def mask
         system("stty -echo")
         yield
       ensure
         puts
         system("stty echo")
       end

       def default_password(password_key)
         if @default_password
           @default_password
         else
           @default_password_key = password_key
           @default_password = mask { ask("default password (will be tried for all future connections)?", :blue) }
         end
       end

       def custom_password(password_key, flush)
         @passwords ||= {}
         if @passwords.has_key?(password_key) && !flush
           @passwords[password_key]
         else
           # Reset the default password if we asked for a custom password for a host
           # that failed with the default password
           if password_key == @default_password_key
             @default_password = nil
             @default_password_key = nil
           end
           @passwords[password_key] = mask { ask("password for: #{password_key}?", :blue) }
         end
       end

       def update_role(role, host)
         say_status :update, "updating #{role} on #{host}"

         prepare_connection_for(host) do |uri|
           connect(uri) do |*ssh_args|
             Net::SSH.start(*ssh_args) do |ssh|
               remote_assets_dir = "#{@remote_chef_path}/assets"
               ssh.exec!("rm -rf #{@remote_chef_path}")
               ssh.exec!("mkdir -p #{@remote_chef_path} #{remote_assets_dir}")

               chef_json = {
                 "run_list" => ["recipe[#{role}]"],
                 "hosts" => @cloud_config["roles"],
                 "assets" => "#{remote_assets_dir}/#{role}"
               }

               chef_json.merge!(@cloud_config["chef_node"]) if @cloud_config["chef_node"]
               chef_json_io = StringIO.new
               chef_json_io.puts(Yajl::Encoder.encode(chef_json))
               chef_json_io.rewind

               ssh.scp.upload!(File.join(BASE_PATH, "clouds", @cloud, "chef.rb"), "#{@remote_chef_path}/chef.rb")
               ssh.scp.upload!(chef_json_io, "#{@remote_chef_path}/chef.json")

               assets_dir = File.join(BASE_PATH, "clouds", @cloud, "assets", role.to_s)
               if File.directory?(assets_dir)
                 say_status :assets, "uploading: #{assets_dir} to #{remote_assets_dir}"
                 ssh.scp.upload!(assets_dir, remote_assets_dir, :recursive => true)
               end

               state = :default
               password = ssh_args.last[:password]
               password_key = "#{ssh_args[0]}@#{ssh_args[1]}:#{ssh_args[2]}"

               unless password
                 password = default_password(password_key)
                 state = :default
               end

               channel = ssh.open_channel do |ch|
                 ch.request_pty do |_, success|
                   raise "could not allocate pty" unless success
                   ch.exec("sudo -p :::deploy_sudo_passwd::: /var/vcap/bosh/bin/chef-solo -c #{@remote_chef_path}/chef.rb -j #{@remote_chef_path}/chef.json") do |_, success|
                     raise "could not execute command" unless success

                     ch.on_data do |_, data|
                       if /:::deploy_sudo_passwd:::/.match(data)
                         if state != :default
                           password = custom_password(password_key, state == :flush)
                           state = :flush
                         else
                           state = :custom
                         end

                         ch.send_data(password + "\n")
                       end
                       $stdout.print(data)
                     end

                     ch.on_extended_data do |_, _, data|
                       $stderr.print(data)
                     end

                   end
                 end
               end

               channel.wait
             end
           end
         end
       end

       def answer_ssh(command, password)
         $expect_verbose = true
         say("==> EXECUTING SSH LOGIN #{command}", :yellow)
         begin
           PTY.spawn(command) do |read_pipe, write_pipe, _|
             loop do
               result = read_pipe.expect(/password:/i)
               next if result.nil?
               write_pipe.puts(password)
             end
             if $!.nil? || $!.is_a?(SystemExit) && $!.success?
               nil
             else
               rtn = $!.is_a?(SystemExit) ? $!.status.exitstatus : 1
               raise "Failed command #{command}" if rtn != 0
             end
           end
         rescue PTY::ChildExited => msg
           raise "Failed command #{command}" if msg.status.exitstatus != 0
         end
       end

       def update_remote_repo(repo, ssh_host, ssh_user, ssh_options)
         Net::SSH.start(ssh_host, ssh_user, ssh_options) do |ssh|
           # git init is safe to run on an existing repo
           ssh.exec!("mkdir -p #{@remote_repo_cache}/#{repo} && cd #{@remote_repo_cache}/#{repo} && git init --bare")
         end

         inside("#{@local_repo_cache}/#{repo}") do
           command = "git push -q ssh://#{ssh_user}@#{ssh_host}:#{ssh_options[:port]}#{@remote_repo_cache}/#{repo} master"
           answer_ssh(command, ssh_options[:password])
         end
       end

       def update_local_repo(repo, uri, scm)
         if scm.upcase == "NONE"
           say_status :syncing, "Preparing git repo from directory #{uri}"

           base_dir = File.basename(uri)
           inside("#{@local_repo_cache}/git") do
             fork{
               cmd = "rsync -a --delete --exclude=\".*/\" #{uri} . && " +
                     "cd #{base_dir} && git init && git add -u && " +
                     # empty git commit reports an error in exitstatus,
                     # so always commit atleast one file (timestamp)
                     "echo #{Time.now.to_f.to_s} > timestamp && " + 
                     "git add * && git commit -q -m 'update'"
               exec("#{cmd}")
             }
             Process.wait
             status = $?
             raise "Failed to create local repo" unless status.exited? && status.exitstatus == 0

             uri = @local_repo_cache + "/git/" + base_dir
           end
         end

         inside("#{@local_repo_cache}/#{repo}") do
           cmd = if File.file?("#{@local_repo_cache}/#{repo}/HEAD")
                   say_status :syncing, "syncing #{repo}"
                   "git fetch #{uri} master:master"
                 else
                   say_status :cloning, "cloning #{repo}"
                   "git clone --bare #{uri} ."
                 end
           fork { exec(cmd) }
           Process.wait
           status = $?
           raise "Failed to sync repo" unless status.exited? && status.exitstatus == 0
         end
       end

       def prepare_connection_for(uri)
         if @gateway
           connect(@gateway) do |host, user, options|
             connection = Net::SSH::Gateway.new(host, user, options)
             begin
               uri = URI.parse("ssh://#{uri}")
               remote_host = uri.host
               remote_port = uri.port || 22
               remote_user = uri.user || @default_user

               connection.open(remote_host, remote_port) do |local_port| 
                 begin
                   @gateway_password_key = "#{remote_user}@#{remote_host}:#{remote_port}"
                   say("==> CONNECTING TO #{@gateway_password_key} VIA #{user}@#{host}:#{options[:port]} ON localhost:#{local_port}", :yellow)
                   yield "#{remote_user}@localhost:#{local_port}"
                 ensure
                   @gateway_password_key = nil
                 end
               end
             ensure
               connection.shutdown!
             end
           end
         else
           say("==> DIRECTLY CONNECTING TO #{uri}", :yellow)
           yield uri
         end
       end

       def connect(uri)
         uri = URI.parse("ssh://#{uri}")

         host = uri.host
         port = uri.port || 22
         user = uri.user || @default_user

         ssh_options = Net::SSH.configuration_for(host, true)
         ssh_options[:config] = false

         # pick the correct user
         user = ssh_options[:username] || ssh_options[:user] || user
         ssh_options.delete(:username)
         ssh_options.delete(:user)

         # might have been changed by ssh_config
         host = ssh_options.fetch(:host_name, host)

         # port is only set via options hash
         ssh_options[:port] ||= port

         state = :public # :public, :default(password), :custom(password)
         @passwords ||= {}
         begin
           password_key = @gateway_password_key || "#{user}@#{host}:#{port}"
           password = case state
                        when :public
                          nil
                        when :default
                          default_password(password_key)
                        when :custom
                          @passwords[password_key] = custom_password(password_key, false)
                        when :flush
                          @passwords[password_key] = custom_password(password_key, true)
                      end

           options = ssh_options.merge(
             :password => password
           )

           options[:auth_methods] = password ? %w(password keyboard-interactive) : %w(publickey hostbased)

           yield host, user, options
         rescue Net::SSH::AuthenticationFailed
           state = case state
                     when :public
                       :default
                     when :default
                       :custom
                     when :custom
                       :flush
                   end
           retry
         end
       end
     end

     desc "deploy CLOUD", "deploy CLOUD"
     method_option :roles, :type => :array
     method_option :metadata, :type => :boolean, :default => true
     def deploy(cloud)
       @cloud = cloud
       say_status :config, "reading cloud configuration"
       config_path = File.join(BASE_PATH, "clouds", cloud, "config.yml")
       raise InvocationError, "Invalid cloud: #{cloud}, missing config file" unless File.file?(config_path)

       host_role_mapping = {}
       @cloud_config = YAML.load_file(config_path)

       @roles = @cloud_config["roles"].dup
       # Filter out all roles that are not needed
       if options.roles
         role_filter = Set.new(options.roles)
         @roles.delete_if {|role, _| !role_filter.include?(role)}
       end

       @roles.each do |role, host|
         (host_role_mapping[host] ||= []) << role
       end

       @remote_chef_path = @cloud_config["paths"]["chef"]
       @remote_repo_cache = @cloud_config["paths"]["repo_cache"]
       @remote_cookbooks_path = @cloud_config["paths"]["cookbooks"]
       raise InvocationError, "Invalid cloud config" unless @remote_repo_cache && @remote_cookbooks_path && @remote_chef_path

       @default_user = @cloud_config["user"]
       raise InvocationError, "Invalid cloud: #{cloud}, missing user" unless @default_user

       if options.metadata
         say_status :status, "Generating cookbook metadata"
         fork { exec "knife cookbook metadata -a -o cookbooks #{COOKBOOKS_PATH}" }
         Process.wait
       end

       @gateway = @cloud_config["gateway"]

       say_status :config, "reading deploy configuration"
       deploy_config = YAML.load_file(File.join(BASE_PATH, "config", "deploy.yml"))
       @local_repo_cache = deploy_config["local_repo_cache"]
       raise InvocationError, "Invalid deploy config" unless @local_repo_cache

       say_status :config, "reading repo configuration"
       role_repo_mapping = {}
       repo_config = YAML.load_file(File.join(BASE_PATH, "config", "repos.yml"))
       repo_config.each do |name, config|
         required_repo = false
         config["roles"].each do |role|
           next unless @roles[role]
           (role_repo_mapping[role] ||= []) << name
           required_repo = true
         end
         scm = config["scm"] || "git"
         update_local_repo(name, config["uri"], scm) if required_repo
       end

       say_status :repos, "checking which repos need to be uploaded"
       host_role_mapping.each do |host, roles|
         roles.each do |role|
           repos = role_repo_mapping[role]
           if repos && !repos.empty?
             prepare_connection_for(host) do |uri|
               repos.each do |repo|
                 say_status :repos, "uploading #{repo} to #{host}"
                 connect(uri) do |*ssh_args|
                   update_remote_repo(repo, *ssh_args)
                 end
               end
             end
           end
         end
       end

       say_status :cookbooks, "uploading cookbooks"
       host_role_mapping.each_key do |host|
         prepare_connection_for(host) do |uri|
           say_status :cookbooks, "uploading cookbooks to #{host}"
           connect(uri) do |ssh_host, ssh_user, ssh_options|
             Net::SSH.start(ssh_host, ssh_user, ssh_options) do |ssh|
               ssh.exec!("mkdir -p #{@remote_cookbooks_path}")
             end

             command = "rsync -avz --delete -e \"ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p #{ssh_options[:port]}\" #{BASE_PATH}/cookbooks/ #{ssh_user}@#{ssh_host}:#{@remote_cookbooks_path}/"
             answer_ssh(command, ssh_options[:password])
           end
         end
       end

       @cloud_config["deploy_order"].each do |role|
         host = @roles[role.to_s]
         update_role(role, host) if host
       end
     end
   end
end
