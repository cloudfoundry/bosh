module IntegrationSupport
  module LicenseBlobsHelper
    def blobstore_license_file_path(version)
      license_index = YAML.load_file(File.join(IntegrationSupport::ClientSandbox.test_release_dir, '.final_builds', 'license', 'index.yml'))
      blobstore_id = license_index['builds'][version]['blobstore_id']

      File.join(IntegrationSupport::ClientSandbox.blobstore_dir, blobstore_id)
    end

    def manifest_sha1_of_license(version)
      license_index = YAML.load_file(File.join(IntegrationSupport::ClientSandbox.test_release_dir, '.final_builds', 'license', 'index.yml'))

      license_index['builds'][version]['sha1']
    end

    def blobstore_tarball_listing(version)
      license_tarball_path = blobstore_license_file_path(version)

      `tar ztf #{license_tarball_path}`.split("\n").sort
    end

    def actual_sha1_of_license(version)
      Digest::SHA1.file(blobstore_license_file_path(version)).hexdigest
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationSupport::LicenseBlobsHelper)
end
