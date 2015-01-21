module Bosh
  module Stemcell
    class StemcellPackager
      def initialize(definition, version, work_path, tarball_path, runner, collection)
        @definition = definition
        @version = version
        @stemcell_build_path = File.join(work_path, 'stemcell')
        @tarball_path = tarball_path
        @runner = runner
        @collection = collection
      end

      def package(disk_format)
        File.delete(stemcell_image_path) if File.exist?(stemcell_image_path)

        runner.configure_and_apply(collection.package_stemcell_stages(disk_format))

        write_manifest(disk_format)
        create_tarball(disk_format)
      end

      private

      attr_reader :definition, :version, :stemcell_build_path, :tarball_path, :runner, :collection

      def write_manifest(disk_format)
        infrastructure = definition.infrastructure

        manifest = {
          'name' => definition.stemcell_name,
          'version' => version.to_s,
          'bosh_protocol' => 1,
          'infrastructure' => infrastructure.name,
          'hypervisor' => infrastructure.hypervisor,
          'operating_system' => definition.operating_system.name,
          'operating_system_version' => definition.operating_system.version,
          'agent' => definition.agent.name,
          'disk_format' => disk_format,
          'sha1' => image_checksum,
          'cloud_properties' => {
            'name' => definition.stemcell_name,
            'version' => version.to_s,
            'infrastructure' => infrastructure.name,
            'disk_format' => disk_format,
            'container_format' => 'bare',
            'os_type' => 'linux',
            'os_distro' => definition.operating_system.name,
            'architecture' => 'x86_64',
          }.merge(infrastructure.additional_cloud_properties)
        }

        manifest_filename = File.join(stemcell_build_path, "stemcell.MF")
        File.open(manifest_filename, "w") do |f|
          f.write(Psych.dump(manifest))
        end
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
