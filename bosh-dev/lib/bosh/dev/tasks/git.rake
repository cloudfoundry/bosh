namespace :git do
  task :pull do
    require 'bosh/dev/shipit_lifecycle'
    Bosh::Dev::ShipitLifecycle.new.pull
  end

  task :push do
    require 'bosh/dev/shipit_lifecycle'
    Bosh::Dev::ShipitLifecycle.new.push
  end

  desc 'Git promote a branch to another'
  task :promote_branch, [:dev_branch, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/git_promoter'
    promoter = Bosh::Dev::GitPromoter.new(Logging.logger(STDERR))
    promoter.promote(args.dev_branch, args.stable_branch)
  end

  desc 'Git tag a sha with a build number'
  task :tag_and_push, [:sha, :build_number] do |_, args|
    require 'logger'
    require 'bosh/dev/git_tagger'
    tagger = Bosh::Dev::GitTagger.new(Logging.logger(STDERR))
    tagger.tag_and_push(args.sha, args.build_number)
  end

  desc 'Add Git commit message hook to append Tracker URL to messages with Tracker story number'
  task :add_tracker_commit_hook do
    sh('ln -Fs ../../bosh-dev/assets/commit-msg.rb .git/hooks/commit-msg')
  end
end
