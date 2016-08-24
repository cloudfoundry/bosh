require 'json'

namespace :stemcell do
  desc 'Create light stemcell from existing stemcell'
  task :build_light, [:stemcell_path, :virtualization_type] do |_, args|
    begin
      require 'bosh/stemcell/aws/light_stemcell'
      require 'bosh/stemcell/archive'
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

  desc 'Download a remote pre-built base OS image'
  task :download_os_image, [:os_image_s3_bucket_name, :os_image_key] do |_, args|
    begin
      require 'bosh/dev/download_adapter'
      require 'bosh/dev/stemcell_dependency_fetcher'

      puts "Using OS image #{args.os_image_key} from #{args.os_image_s3_bucket_name}"

      logger = Logging.logger($stdout)
      downloader = Bosh::Dev::DownloadAdapter.new(logger)
      fetcher = Bosh::Dev::StemcellDependencyFetcher.new(downloader, logger)

      mkdir_p('tmp')
      os_image_path = File.join(Dir.pwd, 'tmp', 'base_os_image.tgz')
      fetcher.download_os_image(
        bucket_name: args.os_image_s3_bucket_name,
        key:         args.os_image_key,
        output_path: os_image_path,
      )

      puts "Successfully downloaded OS image to #{os_image_path}"
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  PINNED_MICRO_VERSION = '257.3'

  desc "Download a remote BOSH micro release, pinned to #{PINNED_MICRO_VERSION}"
  task :download_bosh_micro_release do |_, args|
    begin
      require 'bosh/dev/download_adapter'
      require 'bosh/dev/stemcell_dependency_fetcher'

      puts "Downloading BOSH micro release version '#{PINNED_MICRO_VERSION}'"

      logger = Logging.logger($stdout)
      downloader = Bosh::Dev::DownloadAdapter.new(logger)
      fetcher = Bosh::Dev::StemcellDependencyFetcher.new(downloader, logger)

      mkdir_p('tmp')
      release_path = File.join(Dir.pwd, 'tmp', "bosh-#{PINNED_MICRO_VERSION}.tgz")
      fetcher.download_bosh_micro_release(
        bosh_version: PINNED_MICRO_VERSION,
        output_path: release_path,
      )

      puts "Successfully downloaded BOSH micro release to #{release_path}"
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a stemcell with a remote pre-built base OS image and bosh micro release'
  task :build, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_s3_bucket_name, :os_image_key] do |_, args|
    begin
      require 'bosh/dev/download_adapter'
      require 'bosh/dev/stemcell_dependency_fetcher'

      logger = Logging.logger($stdout)
      downloader = Bosh::Dev::DownloadAdapter.new(logger)
      fetcher = Bosh::Dev::StemcellDependencyFetcher.new(downloader, logger)

      mkdir_p('tmp')
      if 'no' == ENV['BOSH_MICRO_ENABLED']
        release_path = '/dev/null'
      else
        release_path = File.join(Dir.pwd, 'tmp', "bosh-#{PINNED_MICRO_VERSION}.tgz")
        fetcher.download_bosh_micro_release(
          bosh_version: PINNED_MICRO_VERSION,
          output_path: release_path,
        )
      end
      os_image_path = File.join(Dir.pwd, 'tmp', 'base_os_image.tgz')
      fetcher.download_os_image(
        bucket_name: args.os_image_s3_bucket_name,
        key:         args.os_image_key,
        output_path: os_image_path,
      )

      Rake::Task['stemcell:build_with_local_os_image_with_bosh_release_tarball'].invoke(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, os_image_path, release_path)
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a stemcell using a local OS image and bosh micro release'
  task :build_with_local_os_image_with_bosh_release_tarball, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_path, :bosh_release_tarball_path, :build_number] do |_, args|
    begin
      require 'bosh/dev/build'
      require 'bosh/dev/gem_components'
      require 'bosh/stemcell/build_environment'
      require 'bosh/stemcell/definition'
      require 'bosh/stemcell/stage_collection'
      require 'bosh/stemcell/stage_runner'
      require 'bosh/stemcell/stemcell_packager'
      require 'bosh/stemcell/stemcell_builder'

      args.with_defaults(build_number: Bosh::Dev::Build.build_number)

      gem_components = Bosh::Dev::GemComponents.new(args.build_number)
      definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version, args.agent_name, false)
      environment = Bosh::Stemcell::BuildEnvironment.new(
        ENV.to_hash,
        definition,
        args.build_number,
        args.bosh_release_tarball_path,
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

  desc 'Build a stemcell using a local pre-built base OS image'
  task :build_with_local_os_image, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :agent_name, :os_image_path] do |_, args|

    begin
      require 'bosh/dev/download_adapter'
      require 'bosh/dev/stemcell_dependency_fetcher'

      logger = Logging.logger($stdout)
      downloader = Bosh::Dev::DownloadAdapter.new(logger)
      fetcher = Bosh::Dev::StemcellDependencyFetcher.new(downloader, logger)

      mkdir_p('tmp')
      if 'no' == ENV['BOSH_MICRO_ENABLED']
        release_path = '/dev/null'
      else
        release_path = File.join(Dir.pwd, 'tmp', "bosh-#{PINNED_MICRO_VERSION}.tgz")
        fetcher.download_bosh_micro_release(
          bosh_version: PINNED_MICRO_VERSION,
          output_path: release_path,
        )
      end
    rescue RuntimeError => e
      print_help
      raise e
    end

    Rake::Task['stemcell:build_with_local_os_image_with_bosh_release_tarball'].invoke(
      args.infrastructure_name,
      args.hypervisor_name,
      args.operating_system_name,
      args.operating_system_version,
      args.agent_name,
      args.os_image_path,
      release_path,
    )
  end

  def print_help
    puts "\nFor help with stemcell building, see: <https://github.com/cloudfoundry/bosh/blob/master/bosh-stemcell/README.md>\n\n"
  end
end
