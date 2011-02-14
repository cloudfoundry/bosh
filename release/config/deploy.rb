require "config/capistrano-ext/multicloud"

set :application, "bosh_director"
#set :repository,  "git@github.com:vmware-ac/bosh.git"
set :repository,  "/home/mpatil/appcloud/projects/bosh"

set :use_sudo,    false
set :deploy_to,   "/var/vmc/bosh"
set :tmp_dir,     "/var/vmc/tmp"
set :shared_children, %w(system config log pids gems)
set :scm,         :none
set :deploy_via,  :copy
set :git_shallow_clone, 1

set :redis_deploy_to, "/var/vmc/bosh/redis"

def template(name, b = binding)
  path = File.expand_path("../../templates/#{name}.erb", __FILE__)
  File.open(path) {|f| ERB.new(f.read).result(b)}
end

def cloud_template(name, b = binding)
  path = File.expand_path("../../clouds/#{cloud}/templates/#{name}.erb", __FILE__)
  File.open(path) {|f| ERB.new(f.read).result(b)}
end

namespace :redis do
  self.preserve_roles = true

  task :default, :roles => :redis, :except => { :no_release => true } do
    ENV['ROLES'] = "redis"
    update
    configure
    restart
  end

  task :update, :roles => :redis, :except => { :no_release => true } do
    redis_release = Time.now.utc.strftime("%Y%m%d%H%M%S")
    redis_release_path = File.join(redis_deploy_to, redis_release)
    run "mkdir -p #{redis_release_path}"
    run "wget --no-check-certificate https://github.com/antirez/redis/tarball/2.2.0-rc2 -O #{redis_release_path}/redis.tgz"
    run "cd #{redis_release_path} && tar xzf redis.tgz --strip-components=1 && rm redis.tgz"
    run "cd #{redis_release_path} && make && mv src/redis-server #{redis_deploy_to}"
    run "rm -rf #{redis_release_path}"
  end

  task :setup, :roles => :redis, :except => { :no_release => true } do
    put(template("redis/run"), "#{tmp_dir}/redis.run")
    put(template("redis/log/run"), "#{tmp_dir}/redis.log.run")

    run <<-CMD
      #{sudo} mkdir -p #{redis_deploy_to} /etc/service /etc/sv/redis /etc/sv/redis/log /etc/sv/redis/log/main &&
      #{sudo} mv #{tmp_dir}/redis.run /etc/sv/redis/run &&
      #{sudo} mv #{tmp_dir}/redis.log.run /etc/sv/redis/log/run &&
      #{sudo} chmod 755 /etc/sv/redis/run /etc/sv/redis/log/run &&
      #{sudo} chown root:root /etc/sv/redis/run /etc/sv/redis/log/run &&
      #{sudo} chown #{runner}:#{runner} #{redis_deploy_to} &&
      #{sudo} ln -fs /etc/sv/redis /etc/service/
    CMD
  end

  task :restart, :roles => :redis, :except => {:no_release => true} do
    run "#{sudo} sv restart redis"
  end

  task :configure, :roles => :redis, :except => {:no_release => true} do
    put(cloud_template("redis", binding), "#{redis_deploy_to}/redis.conf")
  end

end

namespace :deploy do
  self.preserve_roles = true

  def run_if_role
    begin
      yield
    rescue NoMatchingServersError
    end
  end

  task :default, :roles => [:director, :workers] do
    ENV['ROLES'] = "director,workers"
    update
    configure
    update_gems
    restart
  end

  task :blobstore, :roles => :blobstore do
    ENV['ROLES'] = "blobstore"
    update
    configure_blobstore
    update_blobstore_gems
    restart_blobstore
  end

  task :cold do
    deploy
  end

  task :update_gems, :except => {:no_release => true} do
    run "cd #{current_path}/director && bundle install --deployment --without test,development --path #{shared_path}/gems"
  end

  task :update_blobstore_gems, :except => {:no_release => true} do
    run "cd #{current_path}/simple_blobstore_server && bundle install --deployment --without test,development --path #{shared_path}/gems"
  end

  task :configure, :except => {:no_release => true} do
    configure_director
    configure_workers
  end

  task :configure_director, :roles => :director, :except => {:no_release => true} do
    log_to_stdout = false
    process_name = "director"
    put(cloud_template("director-config", binding), "#{shared_path}/config/bosh-director.yml")
  end

  task :configure_workers, :roles => :workers, :except => {:no_release => true} do
    workers.times do |index|
      log_to_stdout = false
      process_name = "worker-#{index}"
      put(cloud_template("director-config", binding), "#{shared_path}/config/bosh-worker-#{index}.yml")
    end

    log_to_stdout = true
    process_name = "drain_workers"
    put(cloud_template("director-config", binding), "#{shared_path}/config/drain_workers.yml")
  end

  task :configure_blobstore, :roles => :blobstore, :except => {:no_release => true} do
    put(cloud_template("simple_blobstore_server", binding), "#{shared_path}/config/simple_blobstore_server.yml")
  end

  task :finalize_update, :except => {:no_release => true} do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    run <<-CMD
      rm -rf #{latest_release}/log &&
      ln -s #{shared_path}/log #{latest_release}/log
    CMD
  end

  task :setup_host, :except => {:no_release => true} do
    run "#{sudo} cp -n /etc/environment /etc/environment.orig"

    original_environment = ""
    run("cat /etc/environment.orig") do |ch, stream, data|
      case stream
        when :out then original_environment << data
      end
    end

    environment = []
    environment << "TZ=UTC"

    if http_proxy
      environment << "HTTP_PROXY=\"#{http_proxy}\""
      environment << "http_proxy=\"#{http_proxy}\""
      environment << "HTTPS_PROXY=\"#{http_proxy}\""
      environment << "https_proxy=\"#{http_proxy}\""
    end

    if ftp_proxy
      environment << "FTP_PROXY=\"#{ftp_proxy}\""
      environment << "ftp_proxy=\"#{ftp_proxy}\""
    end

    if no_proxy
      environment << "NO_PROXY=\"#{no_proxy}\""
      environment << "no_proxy=\"#{no_proxy}\""
    end

    environment = original_environment + environment.join("\n")

    put(environment, "/tmp/environment")

    run "#{sudo} mv /tmp/environment /etc/environment"

    run "#{sudo} apt-get update -qy && #{sudo} apt-get install -qy --no-install-recommends runit build-essential wget libssl-dev zlib1g-dev libreadline5-dev libxml2-dev genisoimage"

    run <<-CMD
      cd /tmp &&
      rm -rf ruby-1.8.7-p302.tar.gz ruby-1.8.7-p302 &&
      wget -q ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p302.tar.gz &&
      tar -xzf ruby-1.8.7-p302.tar.gz &&
      cd ruby-1.8.7-p302 &&
      ./configure --disable-pthread &&
      make &&
      #{sudo} bash -c "echo; cd /tmp/ruby-1.8.7-p302; make install" &&

      cd /tmp &&
      rm -rf ruby-1.8.7-p302.tar.gz ruby-1.8.7-p302
    CMD

    run <<-CMD
      cd /tmp &&
      rm -rf rubygems-1.3.7.tgz rubygems-1.3.7 &&
      wget -q http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz &&
      tar -xzf rubygems-1.3.7.tgz &&
      #{sudo} bash -c "echo; cd /tmp/rubygems-1.3.7; ruby setup.rb --no-format-executable" &&

      cd /tmp &&
      rm -rf rubygems-1.3.7.tgz rubygems-1.3.7
    CMD

    run <<-CMD
      #{sudo} gem install bundler --no-ri --no-rdoc
    CMD

    run <<-CMD
      #{sudo} mkdir -p #{deploy_to} #{tmp_dir} &&
      #{sudo} chown #{runner}:#{runner} #{deploy_to} #{tmp_dir}
    CMD
  end

  task :setup_runit, :except => {:no_release => true} do
    run_if_role { setup_director_runit }
    run_if_role { setup_workers_runit }
    run_if_role { setup_blobstore_runit }
  end
  after "deploy:setup", "deploy:setup_runit"

  task :setup_director_runit, :roles => :director, :except => {:no_release => true} do
    put(template("director/run"), "#{tmp_dir}/director.run")
    put(template("director/log/run"), "#{tmp_dir}/director.log.run")

    run <<-CMD
      #{sudo} mkdir -p /etc/service /etc/sv/director /etc/sv/director/log /etc/sv/director/log/main &&
      #{sudo} mv #{tmp_dir}/director.run /etc/sv/director/run &&
      #{sudo} mv #{tmp_dir}/director.log.run /etc/sv/director/log/run &&
      #{sudo} chmod 755 /etc/sv/director/run /etc/sv/director/log/run &&
      #{sudo} chown root:root /etc/sv/director/run /etc/sv/director/log/run &&
      #{sudo} ln -fs /etc/sv/director /etc/service/
    CMD
  end

  task :setup_workers_runit, :roles => :workers, :except => {:no_release => true} do
    workers.times do |index|
      put(template("worker/run", binding), "#{tmp_dir}/worker-#{index}.run")
      put(template("worker/log/run", binding), "#{tmp_dir}/worker-#{index}.log.run")

      run <<-CMD
        #{sudo} mkdir -p /etc/service /etc/sv/worker-#{index} /etc/sv/worker-#{index}/log /etc/sv/worker-#{index}/log/main &&
        #{sudo} mv #{tmp_dir}/worker-#{index}.run /etc/sv/worker-#{index}/run &&
        #{sudo} mv #{tmp_dir}/worker-#{index}.log.run /etc/sv/worker-#{index}/log/run &&
        #{sudo} chmod 755 /etc/sv/worker-#{index}/run /etc/sv/worker-#{index}/log/run &&
        #{sudo} chown root:root /etc/sv/worker-#{index}/run /etc/sv/worker-#{index}/log/run &&
        #{sudo} ln -fs /etc/sv/worker-#{index} /etc/service/
      CMD
    end
  end

  task :setup_blobstore_runit, :roles => :blobstore, :except => {:no_release => true} do
    put(template("blobstore/run"), "#{tmp_dir}/blobstore.run")
    put(template("blobstore/log/run"), "#{tmp_dir}/blobstore.log.run")

    run <<-CMD
      #{sudo} mkdir -p /etc/service /etc/sv/blobstore /etc/sv/blobstore/log /etc/sv/blobstore/log/main &&
      #{sudo} mv #{tmp_dir}/blobstore.run /etc/sv/blobstore/run &&
      #{sudo} mv #{tmp_dir}/blobstore.log.run /etc/sv/blobstore/log/run &&
      #{sudo} chmod 755 /etc/sv/blobstore/run /etc/sv/blobstore/log/run &&
      #{sudo} chown root:root /etc/sv/blobstore/run /etc/sv/blobstore/log/run &&
      #{sudo} ln -fs /etc/sv/blobstore /etc/service/
    CMD
  end

  desc "Restarts your application."
  task :restart, :roles => :director, :except => { :no_release => true } do
    drain_workers
    run "#{sudo} sv restart director"
    restart_workers
  end

  task :drain_workers, :roles => :workers, :except => {:no_release => true} do
    workers.times do |index|
      run "#{sudo} sv 2 worker-#{index}"
    end
    run "#{current_path}/director/bin/drain_workers -c #{shared_path}/config/drain_workers.yml"
  end

  task :restart_workers, :roles => :workers, :except => {:no_release => true} do
    workers.times do |index|
      run "#{sudo} sv restart worker-#{index}"
    end
  end

  task :restart_blobstore, :roles => :blobstore, :except => {:no_release => true} do
    run "#{sudo} sv restart blobstore"
  end

end
