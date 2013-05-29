desc "Pulls the most recent code, run all the tests and pushes the repo"
task :shipit do
  sh 'git pull --rebase origin master'

  Rake::Task[:default].invoke

  sh 'git push origin master'
end
