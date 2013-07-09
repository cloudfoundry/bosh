namespace :git do
  task :pull do
    sh 'git pull --rebase origin master'
  end

  task :push do
    sh 'git push origin master'
  end
end
