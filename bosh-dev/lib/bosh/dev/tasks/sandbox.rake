namespace :sandbox do
  task :run do
    require 'bosh/dev/sandbox/main'
    sandbox = Bosh::Dev::Sandbox::Main.new
    sandbox.run
  end
end
