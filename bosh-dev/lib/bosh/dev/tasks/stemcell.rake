namespace :stemcell do
  desc 'Create light stemcell from existing stemcell'
  task :build_light, [:stemcell_path] do |_,args|
    require 'bosh/stemcell/aws/light_stemcell'
    stemcell = Bosh::Stemcell::Archive.new(args.stemcell_path)
    light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell)
    light_stemcell.write_archive
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system and :agent_name and copy to ./tmp/'
  task :build, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_builder'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name, args.agent_name)
    stemcell_path = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_path, File.join('tmp', File.basename(stemcell_path)))
  end




  task :build_os_image, [:operating_system_name, :os_image_path] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/stemcell/archive_handler'
    require 'bosh/stemcell/build_environment'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/os_image_builder'
    require 'bosh/stemcell/stage_collection'
    require 'bosh/stemcell/stage_runner'

    definition = Bosh::Stemcell::Definition.for('null', args.operating_system_name, 'null')
    # pass in /dev/null for the micro release path as the micro is not built at this stage
    environment = Bosh::Stemcell::BuildEnvironment.new(ENV.to_hash, definition, Bosh::Dev::Build.candidate.number, '/dev/null')
    collection = Bosh::Stemcell::StageCollection.new(definition)
    runner = Bosh::Stemcell::StageRunner.new(
      build_path: environment.build_path,
      command_env: environment.command_env,
      settings_file: environment.settings_path,
      work_path: environment.work_path,
    )
    archive_handler = Bosh::Stemcell::ArchiveHandler.new

    builder = Bosh::Stemcell::OsImageBuilder.new(
      environment: environment,
      collection: collection,
      runner: runner,
      archive_handler: archive_handler,
    )
    builder.build(args.os_image_path)
  end

  task :upload_os_image, [:os_image_path, :s3_bucket_name] do |_, args|
    require 'digest'
    require 'bosh/dev/upload_adapter'
    require 'bosh/stemcell/os_image_uploader'

    uploader = Bosh::Stemcell::OsImageUploader.new(adapter: Bosh::Dev::UploadAdapter.new, digester: Digest::SHA256)
    key = uploader.upload(args.s3_bucket_name, File.open(args.os_image_path))
    puts "OS image #{args.os_image_path} uploaded to S3 in bucket #{args.s3_bucket_name} with key #{key}."
  end

  task :build, [:infrastructure_name, :operating_system_name, :agent_name, :os_image_s3_bucket_name, :revision] do |_, args|
  end

  task :build_with_local_os_image, [:infrastructure_name, :operating_system_name, :agent_name, :os_image_path] do |_, args|
  end
end
