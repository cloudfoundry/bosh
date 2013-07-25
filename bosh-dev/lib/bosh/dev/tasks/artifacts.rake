namespace :artifacts do
  namespace :candidates do
    desc 'publishes candidate artifacts to the CI pipeline'
    task :publish, [:stemcell_tgz] do |_, args|
      stemcell_tgz = args.stemcell_tgz || abort('stemcell_tgz is a required parameter')

      require 'bosh/dev/candidate_artifacts'

      candidate_artifacts = Bosh::Dev::CandidateArtifacts.new(stemcell_tgz)
      candidate_artifacts.publish
    end
  end
end
