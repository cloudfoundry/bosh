require "thor"
require 'micro/version'

module VMBuilder
  class Build < Thor
    include Thor::Actions

    attr_reader :template_args

    desc "stemcell", "build stemcell"
    def stemcell
      # TBW
    end

    desc "bosh", "build bosh template VM"
    def bosh
      # TBW
    end

    TEMPLATE_PATH = File.join(File.expand_path("../../templates/micro", __FILE__))
    MICRO_PATH = File.join(File.expand_path("../../../micro", __FILE__))
    AGENT_LIB_PATH = File.join(File.expand_path("../../../agent/lib", __FILE__))

    desc "micro MANIFEST TARBALL", "build micro cloud vm"
    method_options :debug => :boolean, :work_dir => Dir.pwd, :proxy => :string,
      :ovftool => "/usr/lib/vmware/ovftool/ovftool", :iso => :string
    def micro(manifest, tarball)
      timeit "build" do
        Dir.mktmpdir do |tmpdir|
          opts = options.dup # need a writable copy
          check_requirements(opts)

          vmopts = vmbuilder_options(opts)
          check_template(vmopts, opts)

          @template_args = {
            :base => tmpdir
          }

          VMBuilder::Build.source_root(TEMPLATE_PATH)
          say_status "template", "setting up"
          directory(TEMPLATE_PATH, tmpdir)
          Dir.glob("#{tmpdir}/**/*.sh") do |file|
            File.new(file).chmod(0755)
          end

          VMBuilder::Build.source_root(MICRO_PATH)
          directory(MICRO_PATH, "#{tmpdir}/micro")
          File.new("#{tmpdir}/micro/bin/compile").chmod(0755)

          # only copy in the agent files we need
          %w{
            agent/ext.rb agent/util.rb agent/config.rb agent/errors.rb
            agent/version.rb agent/message/base.rb
            agent/message/apply.rb agent/message/compile_package.rb
            agent/monit.rb agent/state.rb agent/template.rb agent/platform.rb
            agent/platform/ubuntu.rb agent/platform/ubuntu/logrotate.rb
            agent/platform/ubuntu/templates/logrotate.erb
          }.each do |path|
            copy_file("#{AGENT_LIB_PATH}/#{path}", "#{tmpdir}/micro/lib/#{path}")
          end

          # copy in deployment manifest & tarball
          copy_file(File.expand_path(manifest), "#{tmpdir}/micro/config/micro.yml")
          copy_file(File.expand_path(tarball), "#{tmpdir}/micro/config/micro.tgz")

          version = VCAP::Micro::Version::VERSION
          vmopts[:config] = File.join(tmpdir, "vmbuilder.cfg")
          inside(opts[:work_dir]) do
            vmbuilder(vmopts)
            FileUtils.mkdir_p("micro")
            ovftool(opts, "ubuntu-esxi/micro.vmx", "micro/micro.vmx")
            FileUtils.mv("micro/micro.vmx", "micro/micro.save")
            lines = File.open("micro/micro.save") {|file| file.readlines}
            File.open("micro/micro.vmx", "w") do |file|
              lines.each do |line|
                if line.match(/^displayname/)
                  file.write("displayname = \"Micro Cloud Foundry v#{version}\"\n")
                else
                  file.write(line)
                end
              end
            end
            FileUtils.rm_rf("micro/micro.save")
            copy_file("#{MICRO_PATH}/README", "micro/README")
            copy_file("#{MICRO_PATH}/RELEASE_NOTES", "micro/RELEASE_NOTES")
            archive("micro", "micro-#{version}.zip")
          end
        end
      end
    end

    no_tasks do
      def check_requirements(options)
        # ovftool
        if options[:ovftool].nil? && ENV["OVFTOOL"]
          options[:ovftool] = ENV["OVFTOOL"]
        end
        unless File.exists?(options[:ovftool])
          say_status "ovftool", "is missing", :red
          exit 1
        end

        unless ENV['TMPDIR']
          say_status "TMPDIR", "is not set", :yellow
        end
      end

      def vmbuilder(opts)
        opts.each do |k, v|
          say_status "arguments", "#{k} = #{v}", :blue
        end
        say_status "vmbuilder", "checking sudo permission"
        `sudo id`
        timeit "vmbuilder" do
          # make sure TMPDIR is set
          `sudo vmbuilder esxi ubuntu #{opts_to_args(opts)}`
          unless $? == 0
            say_status "vmbuilder", "failed", :red
            exit 1
          end
        end
      end

      def ovftool(opts, src, dst)
        timeit "ovftool" do
          `#{opts[:ovftool]} #{src} #{dst}`
        end
      end

      def archive(dir, dst)
        timeit "archive" do
          # `tar zcf #{dst} #{dir}`
          `zip -r #{dst} #{dir}`
        end
      end

      def write_manifest(dir, name, version, protocol)
        File.open("#{dir}/stemcell.MF", 'w') do |f|
          f.puts("---")
          f.puts("name: #{name}")
          f.puts("version: #{version}")
          f.puts("bosh_protocol: #{protocol}")
          f.puts("cloud_properties: {}")
        end
      end

      def timeit(what, &block)
        say_status what, "starting..."
        start = Time.now
        yield
        stop = Time.now
        say_status what, "took #{stop - start}"
      end

      def opts_to_args(opts)
        opts.map {|k, v| "--#{k.to_s.tr("_", "-")} #{v}"}.join(" ")
      end

      def check_template(vmopts, opts)
        if template = opts[:template]
          if File.directory?(template)
            say_status "template", "using #{File.absolute_path(template)}"
            inside(template) do
              check_file(vmopts, "part")
              check_file(vmopts, "execscript")
              check_file(vmopts, "firstboot")
            end
          else
            say_status "template", "directory missing: #{template}", :red
          end
        end
      end

      def check_file(vmopts, name)
        if File.exists?(name)
          vmopts[name.to_sym] = File.absolute_path(name)
          say_status name, "set to #{File.absolute_path(name)}"
        else
          say_status name, "not found", :red
        end
      end

      def vmbuilder_options(options)
        opts = {
          :debug => "",
          :rootsize => "8192"
        }

        if options[:iso]
          if File.exist?(options[:iso])
            opts[:iso] = File.expand_path(options[:iso])
          else
            say_status "iso", "#{options[:iso]} is missing", :red
            exit 1
          end
        end

        if options[:proxy] == "proxy"
          opts[:proxy] = "http://localhost:9999/ubuntu"
        elsif !options[:proxy].nil?
          opts[:proxy] = options[:proxy]
        end

        opts
      end

    end # no_tasks

  end
end
