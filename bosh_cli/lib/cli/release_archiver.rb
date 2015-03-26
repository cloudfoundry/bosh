module Bosh::Cli
  class ReleaseArchiver
    attr_reader :filepath

    def initialize(filepath, manifest, packages, jobs, license = nil)
      @filepath = filepath
      @manifest = manifest
      @packages = packages
      @jobs = jobs
      @license = license

      @build_dir = Dir.mktmpdir
    end

    def build
      FileUtils.copy(manifest, File.join(build_dir, 'release.MF'), :preserve => true)

      packages_dir = FileUtils.mkdir_p(File.join(build_dir, 'packages'))
      header("Copying packages")
      packages.each do |package|
        say(package.name.make_green)
        FileUtils.copy(package.tarball_path, File.join(packages_dir, "#{package.name}.tgz"), :preserve => true)
      end
      nl

      jobs_dir = FileUtils.mkdir_p(File.join(build_dir, 'jobs'))
      header("Copying jobs")
      jobs.each do |job|
        say(job.name.make_green)
        FileUtils.copy(job.tarball_path, File.join(jobs_dir, "#{job.name}.tgz"), :preserve => true)
      end
      nl

      if license
        header("Copying license")
        say("license".make_green)
        nl
        `tar -xzf #{license.tarball_path} -C #{build_dir} 2>&1`
        unless $?.exitstatus == 0
          raise InvalidRelease, "Cannot extract license tarball"
        end
      end

      in_build_dir do
        `tar -czf #{filepath} . 2>&1`
        unless $?.exitstatus == 0
          raise InvalidRelease, "Cannot create release tarball"
        end
        say("Generated #{filepath.make_green}")
        say("Release size: #{pretty_size(filepath).make_green}")
      end
    end

    private

    attr_reader :manifest, :packages, :jobs, :license, :build_dir

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end
