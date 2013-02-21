COMPONENTS = %w( agent_client bosh_aws_bootstrap bosh_aws_cpi bosh_aws_registry blobstore_client
                 bosh_agent bosh_cli bosh_common bosh_cpi bosh_deployer director bosh_encryption health_monitor
                 monit_api bosh_openstack_registry package_compiler ruby_vcloud_sdk ruby_vim_sdk
                 simple_blobstore_server bosh_vcloud_cpi bosh_vsphere_cpi)

COMPONENTS_WITH_PG = %w( director bosh_aws_registry bosh_openstack_registry )

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/BOSH_VERSION").strip
branch  = "v#{version}"

directory "pkg"

COMPONENTS.each do |component|
  namespace component do
    gem     = "pkg/#{component}-#{version}.gem"
    gemspec = "#{component}.gemspec"

    task :update_version_rb do
      glob = root.dup
      glob << "/#{component}/lib/**/version.rb"

      file = Dir[glob].first
      ruby = File.read(file)

      ruby.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")
      white_space = $1
      read_version = $2.gsub('"','').gsub("'","")
      raise "Could not insert VERSION in #{file}" unless white_space

      File.open(file, 'w') { |f| f.write ruby } unless read_version == version
    end

    task :gem => [:update_version_rb, :pkg] do
      if component_needs_update(component, root, version)
        sh "cd #{component} && gem build #{gemspec} && mv #{component}-#{version}.gem #{root}/pkg/"
      else
        sh "cp '#{last_released_component(component, root, version)}' #{root}/pkg/"
      end
    end

    task :gem_with_deps => 'all:prepare_all_gems' do
      dirname = "#{root}/release/src/bosh/#{component}"
      rm_rf dirname
      mkdir_p dirname
      Dir.chdir dirname do
        Bundler::Resolver.resolve(
            Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select { |d| d.name == component }),
            Bundler.definition.index
        ).each do |spec|
          sh "cp /tmp/all_the_gems/#{spec.name}-*.gem ."
          sh "cp /tmp/all_the_gems/pg*.gem ." if COMPONENTS_WITH_PG.include?(component)
        end
      end
    end

    task :install => :gem do
      sh "gem install #{gem}"
    end

    task :prep_release => [:ensure_clean_state, :gem]

    task :push => :gem do
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
      fname = File.join fw, 'CHANGELOG.md'
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
  task :gem => COMPONENTS.map { |f| "#{f}:gem" }

  desc "Build all gems into bosh release/src with their dependencies"
  task :gem_with_deps => COMPONENTS.map { |f| "#{f}:gem_with_deps" }

  desc "Install all gems"
  task :install => COMPONENTS.map { |f| "#{f}:install" }

  desc "Push all gems to rubygems"
  task :push => COMPONENTS.map { |f| "#{f}:push" }

  task :prepare_all_gems => :gem do
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

  desc "Meta task to build all gems, commit a release message, create a git branch and push the gems to rubygems"
  task :release => %w(ensure_clean_state gem commit branch push)
end

def component_needs_update(component, root, version)
  Dir.chdir File.join(root, component) do
    gemspec = Gem::Specification.load File.join(root, component, "#{component}.gemspec")
    last_code_change_time = gemspec.files.map { |file| File::Stat.new(file).mtime }.max

    last_released_component = File.join(root, "release", "src", "bosh", component, "#{component}-#{version}.gem")
    last_released_time = File::Stat.new(last_released_component).mtime

    last_code_change_time > last_released_time
  end
end

def last_released_component(component, root, version)
  Dir.chdir File.join(root, component) do
    File.join(root, "release", "src", "bosh", component, "#{component}-#{version}.gem")
  end
end
