# Copyright (c) 2009-2012 VMware, Inc.

require "rake/tasklib"

class BundlerTask < ::Rake::TaskLib
  def initialize
    namespace "bundler" do
      desc "Install gems"
      task "install" do
        sh("bundle install")
      end

      environments = %w(test development production)

      environments.each do |env|
        desc "Install gems for #{env}"
        task "install:#{env}" do
          Bundler.with_clean_env do
            if ENV.has_key? "RUBYOPT"
              ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
              ENV["RUBYOPT"] = ENV["RUBYOPT"].sub(
                  "-I#{File.expand_path("..", __FILE__)}", "")
            end

            sh("bundle install --without #{(environments - [env]).join(" ")}")
          end
        end
      end
    end
  end
end
