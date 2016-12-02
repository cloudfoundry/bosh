namespace :sandbox do
  task :run do
    require 'bosh/dev/sandbox/main'
    sandbox = Bosh::Dev::Sandbox::Main.from_env
    sandbox.run
  end
end
