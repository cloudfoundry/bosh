require "fileutils"
require "yaml"
require "ostruct"

module Bosh::Cli

  class ReleaseBuilder

    attr_reader :work_dir

    def initialize(work_dir)
      @work_dir        = work_dir
      @build_complete  = false
      @errors          = [ ]

      @current_version = nil
      @new_release_dir = nil
    end

    def build
      old_pwd = Dir.pwd
      Dir.chdir(@work_dir)

      header "Setting up release directory"
      
      say "Looking for current version"

      @current_version = find_current_version

      if @current_version
        say "Found version #{@current_version}"
        @new_version = @current_version + 1
      else
        say "No releases yet, creating the very first one"
        @new_version = 1
      end
      
      say "Creating release version #{@new_version}"
      @new_release_dir = create_release_dir(@new_version)

      header "Building packages"

      # Build packages...

      header "Adding jobs"

      # Add jobs

      header "Generating manifest"

      header "Packing release"

      say "Created release #{@new_version} at '#{@new_release_dir}'".green
      @build_complete = true
    ensure
      Dir.chdir(old_pwd)
      rollback unless @build_complete
    end

    def rollback
      header "Rolling back...".red
      if @release_dir
        say "Deleting #{@new_release_dir}"
        FileUtils.rm_rf(@new_release_dir)
      end

      say("\n")
    end

    private

    def releases_dir
      File.join(work_dir, "releases")
    end

    def find_current_version
      Dir[File.join(releases_dir, "*")].select do |filename|
        File.directory?(filename) && filename =~ /^\d+$/
      end.map do |filename|
        filename.gsub(/\D/, '').to_i
      end.max
    end

    def create_release_dir(version)
      new_dir = File.join(releases_dir, version.to_s)
      FileUtils.mkdir(new_dir)
      FileUtils.mkdir(File.join(new_dir, "packages"))
      FileUtils.mkdir(File.join(new_dir, "jobs"))
      FileUtils.touch(File.join(new_dir, "release.MF"))
      new_dir
    end

  end
  
end
