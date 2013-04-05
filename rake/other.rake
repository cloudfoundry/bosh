desc "Pulls the most recent code, run all the tests and pushes the repo"
task :shipit do
  %x[git pull --rebase origin master]
  abort "Failed to pull, aborting." if $?.exitstatus > 0

  Rake::Task[:default].invoke

  %x[git push origin master]
  abort "Failed to push, aborting." if $?.exitstatus > 0
end