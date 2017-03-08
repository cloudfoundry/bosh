namespace :git do
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
