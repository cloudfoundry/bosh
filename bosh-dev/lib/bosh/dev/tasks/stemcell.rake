namespace :stemcell do
  desc 'Create light stemcell from existing stemcell'
  task :build_light, [:stemcell_path, :virtualization_type] do |_, args|
    begin
      require 'bosh/stemcell/aws/light_stemcell'
      stemcell = Bosh::Stemcell::Archive.new(args.stemcell_path)
      regions = Array(ENV.fetch('BOSH_AWS_REGION', Bosh::Stemcell::Aws::Region::REGIONS))
      light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell, args.virtualization_type, regions)
      light_stemcell.write_archive
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a base OS image for use in stemcells'
  task :build_os_image, [:operating_system_name, :operating_system_version, :os_image_path] do |_, args|
    begin
      require 'bosh/dev/build'
      require 'bosh/stemcell/archive_handler'
      require 'bosh/stemcell/build_environment'
      require 'bosh/stemcell/definition'
      require 'bosh/stemcell/os_image_builder'
      require 'bosh/stemcell/stage_collection'
      require 'bosh/stemcell/stage_runner'

      definition = Bosh::Stemcell::Definition.for('null', 'null', args.operating_system_name, args.operating_system_version, 'null', false)
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
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  task :upload_os_image, [:os_image_path, :s3_bucket_name, :s3_bucket_key] do |_, args|
    require 'bosh/dev/upload_adapter'

    adapter = Bosh::Dev::UploadAdapter.new
    file = adapter.upload(
      bucket_name: args.s3_bucket_name,
      key: args.s3_bucket_key,
      body: File.open(args.os_image_path),
      public: true,
    )
    puts "OS image #{args.os_image_path} version '#{file.version}' uploaded to S3 in bucket '#{args.s3_bucket_name}' with key '#{args.s3_bucket_key}'."
  end

  desc 'Build a stemcell with a remote pre-built base OS image'
  task :build, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_s3_bucket_name, :os_image_key] do |_, args|
    begin
      require 'uri'
      require 'tempfile'
      require 'bosh/dev/download_adapter'

      os_image_versions_file = File.expand_path('../../config/os_image_versions.json', __FILE__)
      os_image_versions = JSON.load(File.open(os_image_versions_file))
      os_image_version = os_image_versions[args.os_image_key]
      puts "Using OS image #{args.os_image_key}, version #{os_image_version}"

      os_image_uri = URI.join('http://s3.amazonaws.com/', "#{args.os_image_s3_bucket_name}/", args.os_image_key)
      os_image_uri.query = URI.encode_www_form([['versionId', os_image_version]])

      Dir.mktmpdir('os-image') do |download_path|
        os_image_path = File.join(download_path, 'base_os_image.tgz')
        downloader = Bosh::Dev::DownloadAdapter.new(Logging.logger($stdout))
        downloader.download(os_image_uri, os_image_path)

        Rake::Task['stemcell:build_with_local_os_image'].invoke(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, os_image_path)
      end

    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a stemcell using a local pre-built base OS image'
  task :build_with_local_os_image, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_path] do |_, args|
    begin
      require 'bosh/dev/build'
      require 'bosh/dev/gem_components'
      require 'bosh/stemcell/build_environment'
      require 'bosh/stemcell/definition'
      require 'bosh/stemcell/stage_collection'
      require 'bosh/stemcell/stage_runner'
      require 'bosh/stemcell/stemcell_packager'
      require 'bosh/stemcell/stemcell_builder'

      # build stemcell
      build = Bosh::Dev::Build.candidate
      gem_components = Bosh::Dev::GemComponents.new(build.number)
      definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, false)
      environment = Bosh::Stemcell::BuildEnvironment.new(
        ENV.to_hash,
        definition,
        build.number,
        build.release_tarball_path,
        args.os_image_path,
      )

      sh(environment.os_image_rspec_command)

      runner = Bosh::Stemcell::StageRunner.new(
        build_path: environment.build_path,
        command_env: environment.command_env,
        settings_file: environment.settings_path,
        work_path: environment.work_path,
      )

      stemcell_building_stages = Bosh::Stemcell::StageCollection.new(definition)

      builder = Bosh::Stemcell::StemcellBuilder.new(
        gem_components: gem_components,
        environment: environment,
        runner: runner,
        definition: definition,
        collection: stemcell_building_stages
      )

      packager = Bosh::Stemcell::StemcellPackager.new(
        definition: definition,
        version: environment.version,
        work_path: environment.work_path,
        tarball_path: environment.stemcell_tarball_path,
        disk_size: environment.stemcell_disk_size,
        runner: runner,
        collection: stemcell_building_stages,
      )

      builder.build

      mkdir_p('tmp')
      definition.disk_formats.each do |disk_format|
        puts "Packaging #{disk_format}..."
        stemcell_tarball = packager.package(disk_format)
        cp(stemcell_tarball, 'tmp')
      end

      sh(environment.stemcell_rspec_command)
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  def print_help
    puts "\nFor help with stemcell building, see: <https://github.com/cloudfoundry/bosh/blob/master/bosh-stemcell/README.md>\n\n"
  end
end
