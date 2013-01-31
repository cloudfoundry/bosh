COMPONENTS = %w( agent_client bosh_aws_bootstrap bosh_aws_cpi bosh_aws_registry blobstore_client
                 bosh_agent bosh_cli bosh_common bosh_cpi bosh_deployer director bosh_encryption health_monitor
                 monit_api bosh_openstack_registry package_compiler ruby_vcloud_sdk ruby_vim_sdk
                 simple_blobstore_server bosh_vcloud_cpi bosh_vsphere_cpi)

COMPONENTS_WITH_PG = %w( director bosh_aws_registry bosh_openstack_registry )

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/BOSH_VERSION").strip
branch     = "v#{version}"

directory "pkg"

COMPONENTS.each do |component|
  namespace component do
    gem     = "pkg/#{component}-#{version}.gem"
    gemspec = "#{component}.gemspec"

    task :clean do
      rm_f gem
    end

    task :update_version_rb do
      glob = root.dup
      glob << "/#{component}/lib/**/version.rb"

      file = Dir[glob].first
      ruby = File.read(file)

      ruby.gsub!(/^(\s*)VERSION = .*?$/, "\\1VERSION = '#{version}'")
      raise "Could not insert VERSION in #{file}" unless $1

      File.open(file, 'w') { |f| f.write ruby }
    end

    task :gem => [:update_version_rb, :pkg] do
      cmd = ""
      cmd << "cd #{component} && "
      cmd << "gem build #{gemspec} && mv #{component}-#{version}.gem #{root}/pkg/"
      sh cmd
    end

    task :gem_with_deps => 'all:prepare_all_gems' do
      dirname = "#{root}/release/src/bosh/#{component}"
      rm_rf dirname
      mkdir_p dirname
      Dir.chdir dirname do
        Bundler::Resolver.resolve(
            Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select{|d| d.name == component}),
            Bundler.definition.index
        ).each do |spec|
          sh "cp /tmp/all_the_gems/#{spec.name}-*.gem ."
          sh "cp /tmp/all_the_gems/pg*.gem ." if COMPONENTS_WITH_PG.include?(component)
        end
      end
    end

    task :build => [:clean, :gem]
    task :build_with_deps => [:clean, :gem_with_deps]

    task :install => :build do
      sh "gem install #{gem}"
    end

    task :prep_release => [:ensure_clean_state, :build]

    task :push => :build do
      sh "gem push #{gem}"
    end
  end
end

namespace :changelog do
  task :release_date do
    COMPONENTS.each do |fw|
      require 'date'
      replace = '\1(' + Date.today.strftime('%B %d, %Y') + ')'
      fname = File.join fw, 'CHANGELOG.md'

      contents = File.read(fname).sub(/^([^(]*)\(unreleased\)/, replace)
      File.open(fname, 'wb') { |f| f.write contents }
    end
  end

  task :release_summary do
    COMPONENTS.each do |fw|
      puts "## #{fw}"
      fname    = File.join fw, 'CHANGELOG.md'
      contents = File.readlines fname
      contents.shift
      changes = []
      changes << contents.shift until contents.first =~ /^\*Bosh \d+\.\d+\.\d+/
      puts changes.reject { |change| change.strip.empty? }.join
      puts
    end
  end
end

namespace :all do
  desc "Build all gems"
  task :build   => COMPONENTS.map { |f| "#{f}:build"   }

  desc "Build all gems into bosh release/src with their dependencies"
  task :build_with_deps   => COMPONENTS.map { |f| "#{f}:build_with_deps"   }

  desc "Install all gems"
  task :install => COMPONENTS.map { |f| "#{f}:install" }

  desc "Push all gems to rubygems"
  task :push    => COMPONENTS.map { |f| "#{f}:push"    }

  task :prepare_all_gems => :build do
    rm_rf "/tmp/all_the_gems"
    mkdir_p "/tmp/all_the_gems"
    sh "cp #{root}/pkg/*.gem /tmp/all_the_gems"
    sh "cp #{root}/vendor/cache/*.gem /tmp/all_the_gems"
  end

  task :ensure_clean_state do
    unless `git status -s | grep -v BOSH_VERSION`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV['SKIP_BRANCH'] || `git branch -ra | grep #{branch}`.strip.empty?
      abort "[ABORTING] `git branch` shows that #{branch} already exists. Has this version already\n"\
            "           been released? Git branching can be skipped by setting SKIP_BRANCH=1"
    end
  end

  task :commit do
    File.open('pkg/commit_message.txt', 'w') do |f|
      f.puts "# Preparing for #{version} release\n"
      f.puts
      f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
    end

    sh "git add . && git commit --verbose --template=pkg/commit_message.txt"
    rm_f "pkg/commit_message.txt"
  end

  task :branch do
    sh "git checkout -b #{branch}"
    sh "git push origin #{branch}"
  end

  desc "Meta taks to build all gems, commit a release message, create a git branch and push the gems to rubygems"
  task :release => %w(ensure_clean_state build commit branch push)
end
