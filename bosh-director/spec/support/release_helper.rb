require 'psych'
require 'tmpdir'
require 'fileutils'
require 'digest/sha1'

module Bosh::Director::Test
  class ReleaseHelper
    # Creates release tarball using provided manifest.
    # Actual bits are dummy but all specs are meant to satisfy the release.
    # Checksums are filled in automatically to satisfy integrity checks.
    # @param [Hash] manifest Release manifest
    # @return [String] Directory containing release.tgz
    def create_release_tarball(manifest)
      tmp_dir = Dir.mktmpdir
      release_dir = Dir.mktmpdir

      jobs_dir = File.join(tmp_dir, "jobs")
      packages_dir_name = !!manifest["compiled_packages"] ? "compiled_packages" : "packages"
      packages_dir = File.join(tmp_dir, packages_dir_name)

      FileUtils.mkdir(jobs_dir)
      FileUtils.mkdir(packages_dir)

      manifest["jobs"].each do |job|
        job_dir = File.join(jobs_dir, job["name"])
        FileUtils.mkdir(job_dir)
        spec = {
          "name" => job["name"],
          "templates" => job["templates"],
          packages_dir_name => job[packages_dir_name]
        }
        File.open(File.join(job_dir, "job.MF"), "w") do |f|
          Psych.dump(spec, f)
        end

        templates_dir = File.join(job_dir, "templates")
        FileUtils.mkdir(templates_dir)

        Dir.chdir(templates_dir) do
          spec["templates"].each_key do |template_path|
            FileUtils.mkdir_p(File.dirname(template_path))
            File.open(template_path, "w") do |f|
              f.write("dummy template")
            end
          end
        end

        File.open(File.join(job_dir, "monit"), "w") do |f|
          f.write("dummy monit file")
        end

        Dir.chdir(jobs_dir) do
          tar_out = `tar -C #{job_dir} -czf #{job["name"]}.tgz . 2>&1`
          if $?.exitstatus != 0
            raise "Cannot create job: #{tar_out}"
          end

          job["sha1"] ||= Digest::SHA1.file("#{job["name"]}.tgz").hexdigest
        end
        FileUtils.rm_rf(job_dir)
      end

      manifest[packages_dir_name].each do |package|
        package_dir = File.join(packages_dir, package["name"])
        FileUtils.mkdir(package_dir)
        File.open(File.join(package_dir, "packaging"), "w") do |f|
          f.write("dummy packaging")
        end

        Dir.chdir(packages_dir) do
          tar_out = `tar -C #{package_dir} -czf #{package["name"]}.tgz . 2>&1`
          if $?.exitstatus != 0
            raise "Cannot create package: #{tar_out}"
          end

          package["sha1"] ||= Digest::SHA1.file("#{package["name"]}.tgz").hexdigest
        end
        FileUtils.rm_rf(package_dir)
      end

      File.open(File.join(tmp_dir, "release.MF"), "w") do |f|
        Psych.dump(manifest, f)
      end

      Dir.chdir(release_dir) do
        tar_out = `tar -C #{tmp_dir} -czf release.tgz . 2>&1`
        if $?.exitstatus != 0
          raise "Cannot create release: #{tar_out}"
        end
      end

      FileUtils.cp_r(release_dir, "/tmp/foobar")

      release_dir
    end
  end
end
