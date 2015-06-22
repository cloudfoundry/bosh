module Bosh
  module Stemcell
    class StemcellPackager
      def initialize(options = {})
        @definition = options.fetch(:definition)
        @version = options.fetch(:version)
        @stemcell_build_path = File.join(options.fetch(:work_path), 'stemcell')
        @tarball_path = options.fetch(:tarball_path)
        @disk_size = options.fetch(:disk_size)
        @runner = options.fetch(:runner)
        @collection = options.fetch(:collection)
      end

      def package(disk_format)
        File.delete(stemcell_image_path) if File.exist?(stemcell_image_path)

        runner.configure_and_apply(collection.package_stemcell_stages(disk_format))

        write_manifest(disk_format)
        create_tarball(disk_format)
      end

      private

      attr_reader :definition, :version, :stemcell_build_path, :tarball_path, :disk_size, :runner, :collection

      def write_manifest(disk_format)
        manifest_filename = File.join(stemcell_build_path, "stemcell.MF")
        File.open(manifest_filename, "w") do |f|
          f.write(Psych.dump(manifest(disk_format)))
        end
      end

      def manifest(disk_format)
        infrastructure = definition.infrastructure

        stemcell_name = "bosh-#{definition.stemcell_name(disk_format)}"
        {
          'name' => stemcell_name,
          'version' => version.to_s,
          'bosh_protocol' => 1,
          'sha1' => image_checksum,
          'operating_system' => "#{definition.operating_system.name}-#{definition.operating_system.version}",
          'cloud_properties' => manifest_cloud_properties(disk_format, infrastructure, stemcell_name)
        }
      end

      def manifest_cloud_properties(disk_format, infrastructure, stemcell_name)
        {
            'name' => stemcell_name,
            'version' => version.to_s,
            'infrastructure' => infrastructure.name,
            'hypervisor' => infrastructure.hypervisor,
            'disk' => disk_size,
            'disk_format' => disk_format,
            'container_format' => 'bare',
            'os_type' => 'linux',
            'os_distro' => definition.operating_system.name,
            'architecture' => 'x86_64',
        }.merge(infrastructure.additional_cloud_properties)
      end

      def create_tarball(disk_format)
        stemcell_name = ArchiveFilename.new(version, definition, 'bosh-stemcell', disk_format).to_s
        tarball_name = File.join(tarball_path, stemcell_name)

        Dir.chdir(stemcell_build_path) do
          system("tar zcf #{tarball_name} *")
        end

        tarball_name
      end

      def image_checksum
        `shasum -a 1 #{stemcell_image_path}`.split(/\s/).first
      end

      def stemcell_image_path
        File.join(stemcell_build_path, 'image')
      end
    end
  end
end
