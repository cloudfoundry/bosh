module Bosh::Cli

  class PackageBuilder

    attr_reader :name, :globs, :dependencies, :package_dir, :sources_dir, :metadata_dir, :tarball_path

    def initialize(spec, release_dir, sources_dir = nil)
      spec = YAML.load_file(spec) if spec.is_a?(String) && File.file?(spec)
      
      @name  = spec["name"]
      @globs = spec["files"]

      @dependencies = spec["dependencies"].is_a?(Array) ? spec["dependencies"] : []
      
      if @name.blank?
        raise InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidPackage, "Package name should be a valid Bosh identifier"
      end

      unless @globs.is_a?(Array) && @globs.size > 0
        raise InvalidPackage, "Package '#{@name}' doesn't include any files"
      end

      @packages_dir  = File.join(release_dir, "packages")
      @package_dir   = File.join(@packages_dir, @name)
      @metadata_dir  = File.join(@package_dir, "data")
      @sources_dir   = sources_dir || File.join(release_dir, "src")
      @tarballs_dir  = File.join(release_dir, "tmp", "packages")

      FileUtils.mkdir_p(@metadata_dir)
      FileUtils.mkdir_p(@tarballs_dir)
    end

    def build
      copy_files
      generate_tarball

      copy_tarball if version_missing?
      store_version if new_version?

      @build_complete = true
    ensure
      rollback unless @build_complete
    end

    def rollback
      # TBD
    end

    def copy_files
      copied = 0

      in_sources_dir do
        files.each do |filename|
          destination = File.join(build_dir, strip_package_name(filename))

          if File.directory?(filename)
            FileUtils.mkdir_p(destination)
          else
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(filename, destination)
            copied += 1
          end
        end
      end

      in_metadata_dir do
        Dir["*"].each do |filename|
          destination = File.join(build_dir, filename)
          if File.exists?(destination)
            raise InvalidPackage, "Package '#{name}' has '#{filename}' file that conflicts with one of its metadata files"
          end
          FileUtils.cp(filename, destination)
          copied += 1
        end
      end

      @files_copied = true
      copied
    end

    def generate_tarball
      FileUtils.mkdir_p(File.dirname(last_build_path))

      copy_files unless @files_copied

      in_build_dir do
        `tar -czf #{last_build_path} . 2>&1`
        raise InvalidPackage, "Cannot create package tarball" unless $?.exitstatus == 0
      end

      @tarball_generated = true
    end
    
    def copy_tarball
      generate_tarball unless @tarball_generated
      FileUtils.mv(last_build_path, tarball_path)
    end

    def tarball_checksum
      if File.exists?(tarball_path)
        @tarball_checkum ||= Digest::SHA1.hexdigest(File.read(tarball_path))
      else
        raise RuntimeError, "cannot read checksum for not yet generated package"
      end
    end

    def tarball_path
      File.join(@tarballs_dir, "#{name}-#{guess_version}.tgz")      
    end

    def files
      @files ||= resolve_globs
    end

    def signature
      @signature ||= make_signature
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end    

    def reload
      @files     = nil
      @signature = nil
      self
    end

    def store_version
      File.open(versions_file, "a") do |f|
        f.puts("%s:%s" % [ signature, guess_version])
      end
    end

    def new_version?
      existing_versions[signature].nil?
    end

    def version_missing?
      !File.exists?(File.join(@tarballs_dir, "#{name}-#{guess_version}.tgz"))
    end

    def guess_version
      existing_versions[signature] || existing_versions.values.max.to_i + 1
    end
    alias_method :version, :guess_version

    def existing_versions
      @existing_versions ||= read_versions
    end

    # lib/sphinx-0.9.tar.gz => lib/sphinx-0.9.tar.gz
    # but "cloudcontroller/lib/cloud.rb => lib/cloud.rb"
    def strip_package_name(filename)
      pos = filename.index(File::SEPARATOR)
      if pos && filename[0..pos-1] == @name
        filename[pos+1..-1]
      else
        filename
      end
    end

    private

    def last_build_path
      File.join(@tarballs_dir, "#{name}_last_build.tgz")
    end

    def resolve_globs
      in_sources_dir do
        @globs.map { |glob| Dir[glob] }.flatten.sort
      end
    end

    def make_signature
      contents = ""
      # First, source files (+ permissions)
      in_sources_dir do
        contents << files.sort.map { |file|
          "%s%s%s" % [ file, File.directory?(file) ? nil : File.read(file), File.stat(file).mode.to_s(8) ]
        }.join("")
      end
      # Second, metadata files (packaging, migrations, whatsoever)
      in_metadata_dir do
        contents << Dir["*"].sort.map { |file|
          "%s%s" % [ file, File.directory?(file) ? nil : File.read(file) ]
        }.join("")
      end

      Digest::SHA1.hexdigest(contents)      
    end

    def versions_file
      File.join(@package_dir, "versions")
    end

    def read_versions
      return { } unless File.file?(versions_file) && File.readable?(versions_file)

      File.readlines(versions_file).inject({ }) do |h, line|
        h[$1] = $2.to_i if line =~ /^\s*([0-9a-fA-F]+):(\d+)\s*$/
        h
      end
    end

    def in_sources_dir(&block)
      Dir.chdir(sources_dir) { yield }
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

    def in_metadata_dir(&block)
      if File.directory?(metadata_dir)
        Dir.chdir(metadata_dir) { yield }
      end
    end

  end

end
