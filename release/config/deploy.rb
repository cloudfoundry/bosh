require "config/capistrano-ext/multicloud"

set :application, "bosh_director"
set :repository,  "git@github.com:vmware-ac/bosh.git"

set :use_sudo, false
set :deploy_to,   "/var/b29/bosh"
set :shared_children, %w(system config log pids)
set :scm, :git
set :deploy_via, :copy

namespace :deploy do

  task :default do
    update
    configure
    update_gems
    restart
  end

  task :cold do
    deploy
  end

  task :update_gems, :except => {:no_release => true} do
    run "cd #{current_path}/director && bundle install --deployment --without test,development"
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

    run "#{sudo} apt-get update -qy && #{sudo} apt-get install -qy --no-install-recommends runit build-essential wget libssl-dev zlib1g-dev libreadline5-dev libxml2-dev"

    run <<-CMD
      cd /tmp &&
      rm -rf ruby-1.8.7-p302.tar.gz ruby-1.8.7-p302 &&
      wget -q ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p302.tar.gz &&
      tar -xzf ruby-1.8.7-p302.tar.gz &&
      cd ruby-1.8.7-p302 &&
      ./configure &&
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
      #{sudo} mkdir -p /var/b29/bosh /var/b29/tmp &&
      #{sudo} chown #{runner}:#{runner} /var/b29/bosh /var/b29/tmp
    CMD
  end

  task :setup_runit, :except => {:no_release => true} do
    setup_director_runit
    setup_workers_runit
  end
  after "deploy:setup", "deploy:setup_runit"

  task :setup_director_runit, :roles => :director, :except => {:no_release => true} do
    put(template("director/run"), "/var/b29/tmp/director.run")
    put(template("director/log/run"), "/var/b29/tmp/director.log.run")

    run <<-CMD
      #{sudo} mkdir -p /etc/service /etc/sv/director /etc/sv/director/log /etc/sv/director/log/main &&
      #{sudo} mv /var/b29/tmp/director.run /etc/sv/director/run &&
      #{sudo} mv /var/b29/tmp/director.log.run /etc/sv/director/log/run &&
      #{sudo} chmod 755 /etc/sv/director/run /etc/sv/director/log/run &&
      #{sudo} chown root:root /etc/sv/director/run /etc/sv/director/log/run &&
      #{sudo} ln -fs /etc/sv/director /etc/service/
    CMD
  end

  task :setup_workers_runit, :roles => :workers, :except => {:no_release => true} do
    workers.times do |index|
      put(template("worker/run", binding), "/var/b29/tmp/worker-#{index}.run")
      put(template("worker/log/run", binding), "/var/b29/tmp/worker-#{index}.log.run")

      run <<-CMD
        #{sudo} mkdir -p /etc/service /etc/sv/worker-#{index} /etc/sv/worker-#{index}/log /etc/sv/worker-#{index}/log/main &&
        #{sudo} mv /var/b29/tmp/worker-#{index}.run /etc/sv/worker-#{index}/run &&
        #{sudo} mv /var/b29/tmp/worker-#{index}.log.run /etc/sv/worker-#{index}/log/run &&
        #{sudo} chmod 755 /etc/sv/worker-#{index}/run /etc/sv/worker-#{index}/log/run &&
        #{sudo} chown root:root /etc/sv/worker-#{index}/run /etc/sv/worker-#{index}/log/run &&
        #{sudo} ln -fs /etc/sv/worker-#{index} /etc/service/
      CMD
    end
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

  def template(name, b = binding)
    path = File.expand_path("../../templates/#{name}.erb", __FILE__)
    File.open(path) {|f| ERB.new(f.read).result(b)}
  end

  def cloud_template(name, b = binding)
    path = File.expand_path("../../clouds/#{cloud}/templates/#{name}.erb", __FILE__)
    File.open(path) {|f| ERB.new(f.read).result(b)}
  end

end