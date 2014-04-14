namespace :stemcell do
  desc 'Create light stemcell from existing stemcell'
  task :build_light, [:stemcell_path] do |_,args|
    require 'bosh/stemcell/aws/light_stemcell'
    stemcell = Bosh::Stemcell::Archive.new(args.stemcell_path)
    light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell)
    light_stemcell.write_archive
  end

  desc 'Build a base OS image for use in stemcells'
  task :build_os_image, [:operating_system_name, :operating_system_version, :os_image_path] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/stemcell/archive_handler'
    require 'bosh/stemcell/build_environment'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/os_image_builder'
    require 'bosh/stemcell/stage_collection'
    require 'bosh/stemcell/stage_runner'

    definition = Bosh::Stemcell::Definition.for('null', args.operating_system_name, args.operating_system_version, 'null')
    # pass in /dev/null for the micro release path as the micro is not built at this stage
    environment = Bosh::Stemcell::BuildEnvironment.new(
      ENV.to_hash,
      definition,
      Bosh::Dev::Build.candidate.number,
      '/dev/null',
      args.os_image_path,
    )
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

    sh(environment.os_image_rspec_command)
  end

  task :upload_os_image, [:os_image_path, :s3_bucket_name] do |_, args|
    require 'digest'
    require 'bosh/dev/upload_adapter'
    require 'bosh/stemcell/os_image_uploader'

    uploader = Bosh::Stemcell::OsImageUploader.new(adapter: Bosh::Dev::UploadAdapter.new, digester: Digest::SHA256)
    key = uploader.upload(args.s3_bucket_name, File.open(args.os_image_path))
    puts "OS image #{args.os_image_path} uploaded to S3 in bucket #{args.s3_bucket_name} with key #{key}."
  end

  task :build, [:infrastructure_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_s3_bucket_name, :key] do |_, args|
    require 'uri'
    require 'tempfile'
    require 'bosh/dev/download_adapter'

    os_image_uri = URI.join('http://s3.amazonaws.com/', "#{args.os_image_s3_bucket_name}/", args.key)
    Dir.mktmpdir('os-image') do |download_path|
      os_image_path = File.join(download_path, 'base_os_image.tgz')
      downloader = Bosh::Dev::DownloadAdapter.new(Logger.new($stdout))
      downloader.download(os_image_uri, os_image_path)

      Rake::Task['stemcell:build_with_local_os_image'].invoke(args.infrastructure_name, args.operating_system_name, args.operating_system_version, args.agent_name, os_image_path)
    end
  end

  desc 'Build a stemcell using a pre-built base OS image'
  task :build_with_local_os_image, [:infrastructure_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_path] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/gem_components'
    require 'bosh/stemcell/build_environment'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/stage_collection'
    require 'bosh/stemcell/stage_runner'
    require 'bosh/stemcell/stemcell_builder'

    # build stemcell
    build = Bosh::Dev::Build.candidate
    gem_components = Bosh::Dev::GemComponents.new(build.number)
    definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.operating_system_name, args.operating_system_version, args.agent_name)
    environment = Bosh::Stemcell::BuildEnvironment.new(
      ENV.to_hash,
      definition,
      build.number,
      build.release_tarball_path,
      args.os_image_path,
    )

    sh(environment.os_image_rspec_command)

    collection = Bosh::Stemcell::StageCollection.new(definition)
    runner = Bosh::Stemcell::StageRunner.new(
      build_path: environment.build_path,
      command_env: environment.command_env,
      settings_file: environment.settings_path,
      work_path: environment.work_path,
    )

    builder = Bosh::Stemcell::StemcellBuilder.new(
      gem_components: gem_components,
      environment: environment,
      collection: collection,
      runner: runner,
    )
    builder.build

    sh(environment.stemcell_rspec_command)

    mkdir_p('tmp')
    cp(environment.stemcell_file, 'tmp')
  end
end
