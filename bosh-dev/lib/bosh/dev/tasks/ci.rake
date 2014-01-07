namespace :ci do
  namespace :run do
    desc 'Meta task to run spec:unit and rubocop'
    task unit: %w(spec:unit)

    desc 'Meta task to run spec:integration'
    task integration: %w(spec:integration)

    desc 'Task that installs a go binary locally and runs go agent tests'
    task :go_agent_tests do
      mkdir = 'mkdir -p tmp'
      curl = 'curl https://go.googlecode.com/files/go1.2.linux-amd64.tar.gz > tmp/go.tgz'
      untar = 'tar xzf tmp/go.tgz -C tmp'
      go_tests = 'PATH=`pwd`/tmp/go/bin:$PATH go_agent/bin/test'

      exec "#{mkdir} && #{curl} && #{untar} && #{go_tests}"
    end
  end

  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/build'
    require 'bosh/dev/gems_generator'
    build = Bosh::Dev::Build.candidate
    gems_generator = Bosh::Dev::GemsGenerator.new(build)
    gems_generator.generate_and_upload
  end

  desc 'Publish CI pipeline BOSH release to S3'
  task publish_bosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_release_publisher'
    build = Bosh::Dev::Build.candidate
    Bosh::Dev::BoshReleasePublisher.setup_for(build).publish
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system, and :agent_name and publish to S3'
  task :publish_stemcell, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_builder'
    require 'bosh/dev/stemcell_publisher'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name, args.agent_name)
    stemcell_path = stemcell_builder.build_stemcell

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build
    stemcell_publisher.publish(stemcell_path)
  end

  task :publish_stemcell_in_vm, [:infrastructure_name, :operating_system_name, :vm_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_vm'
    stemcell_vm = Bosh::Dev::StemcellVm.new(args.to_hash, ENV)
    stemcell_vm.publish
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end

  task :promote, [:candidate_build_number, :candidate_sha, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/promoter'
    promoter = Bosh::Dev::Promoter.build(args.to_hash)
    promoter.promote
  end
end
