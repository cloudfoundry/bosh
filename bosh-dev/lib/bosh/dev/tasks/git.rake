namespace :git do
  task :pull do
    sh 'git pull --rebase origin master'
  end

  task :push do
    sh 'git push origin master'
  end

  task :promote_branch, [:dev_branch, :stable_branch] do |_, args|
    require 'bosh/dev/git_promoter'

    puts "Promoting local git branch #{args.dev_branch} to remote branch #{args.stable_branch}"

    Bosh::Dev::GitPromoter.new.promote(args.dev_branch, args.stable_branch)
  end
end
