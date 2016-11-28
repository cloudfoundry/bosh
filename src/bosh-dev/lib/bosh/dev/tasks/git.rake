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
    commit_hook = File.join(File.dirname(__FILE__),'..', '..', '..', '..', 'assets', 'commit-msg.rb')

    if File.exist?(commit_hook)
      sh("ln -Fs #{commit_hook} .git/hooks/commit-msg")
    else
      raise "File #{commit_hook} expected to exist but does not."
    end
  end
end
