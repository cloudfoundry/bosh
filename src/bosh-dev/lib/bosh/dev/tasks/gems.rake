require 'pathname'

def base_dir
  Pathname(__FILE__).parent.parent.parent.parent.parent.parent
end

def gems
  Dir["#{base_dir}/*/*.gemspec"].map { |path| Pathname(path).parent.basename.to_s }
end

namespace :gems do
  desc 'Fix Gemfiles to include other bosh gems referenced from gemspecs by relative path (otherwise you would get a released version)'
  task :fix_gemfiles do
    gems.each do |gem|
      gemfile = base_dir.join(gem).join('Gemfile')
      gemspec = base_dir.join(gem).join("#{gem}.gemspec")

      gemspec_deps = File.read(gemspec).split(/\n/).map { |line| line =~ /add_dependency.*['"](bosh[^'"]+)['"]/; $1 }.compact

      File.open(gemfile, 'w') do |f|
        f << "source 'https://rubygems.org'\n"
        f << "\n"
        gemspec_deps.sort.each do |dep|
          if base_dir.join(dep).exist? # e.g. bosh_vcloud_cpi doesn't exist
            f << "gem '#{dep}', path: '../#{dep}'\n"
          end
        end
        f << "\n"
        f << "gemspec\n"
      end
    end
  end

  desc 'Try running `bundle exec spec` for each gem'
  task :try_spec do
    gems.each do |gem|
      spec_helper_output = `cd #{gem} && bundle exec rspec ./spec/spec_helper.rb 2>&1`
      if $? != 0
        puts "#{gem}:"
        puts spec_helper_output
        puts ""
        puts ""
        puts ""
      end
    end
  end

  desc 'Try running `bundle` for each gem'
  task :bundle do
    gems.each do |gem|
      spec_helper_output = `cd #{gem} && bundle install 2>&1`
      if $? != 0
        puts "#{gem}:"
        puts spec_helper_output
        puts ""
        puts ""
        puts ""
      end
    end
  end
end
