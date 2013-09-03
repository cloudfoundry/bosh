require 'bosh/dev/gem_components'

COMPONENTS = Bosh::Dev::GemComponents.new
COMPONENTS.each do |component|
  namespace component do
    gemspec = "#{component}.gemspec"

    task :update_version_rb do #yes
      glob = File.join(COMPONENTS.root, component, 'lib', '**', 'version.rb')

      version_file_path = Dir[glob].first
      file_contents = File.read(version_file_path)

      file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{COMPONENTS.version}'")
      read_version = $2.gsub(/\A['"]|['"]\Z/, '') # remove only leading and trailing single or double quote

      File.open(version_file_path, 'w') { |f| f.write file_contents } unless read_version == COMPONENTS.version
    end

    task :pre_stage_latest => [:update_version_rb, :pkg] do #yes
      if COMPONENTS.component_needs_update(component, COMPONENTS.root, COMPONENTS.version)
        sh "cd #{component} && gem build #{gemspec} && mv #{component}-#{COMPONENTS.version}.gem #{COMPONENTS.root}/pkg/gems/"
      else
        sh "cp '#{COMPONENTS.last_released_component(component, COMPONENTS.root, COMPONENTS.version)}' #{COMPONENTS.root}/pkg/gems/"
      end
    end

    task :finalize_release_directory => 'all:stage_with_dependencies' do # yes
      dirname = "#{COMPONENTS.root}/release/src/bosh/#{component}"

      rm_rf dirname
      mkdir_p dirname
      gemfile_lock_path = File.join(COMPONENTS.root, 'Gemfile.lock')
      lockfile = Bundler::LockfileParser.new(File.read(gemfile_lock_path))
      Dir.chdir dirname do
        Bundler::Resolver.resolve(
            Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select { |d| d.name == component }),
            Bundler.definition.index,
            {},
            lockfile.specs
        ).each do |spec|
          sh "cp /tmp/all_the_gems/#{Process.pid}/#{spec.name}-*.gem ."
          sh "cp /tmp/all_the_gems/#{Process.pid}/pg*.gem ." if COMPONENTS.has_db?(component)
          sh "cp /tmp/all_the_gems/#{Process.pid}/mysql*.gem ." if COMPONENTS.has_db?(component)
        end
      end
    end
  end
end

namespace :all do
  desc 'Prepare latest gem versions for staging'
  task :pre_stage_latest do # yes
    rm_rf 'pkg'
    mkdir_p 'pkg/gems'
    COMPONENTS.map { |f| Rake::Task["#{f}:pre_stage_latest"].invoke  }
  end

  desc 'Copy all staged gems into appropriate release subdirectories'
  task :finalize_release_directory => COMPONENTS.map { |f| "#{f}:finalize_release_directory" } do # yes
    rm_rf "/tmp/all_the_gems/#{Process.pid}"
  end

  task :stage_with_dependencies => :pre_stage_latest do # yes
    mkdir_p "/tmp/all_the_gems/#{Process.pid}"
    sh "cp #{COMPONENTS.root}/pkg/gems/*.gem /tmp/all_the_gems/#{Process.pid}"
    sh "cp #{COMPONENTS.root}/vendor/cache/*.gem /tmp/all_the_gems/#{Process.pid}"
  end
end
