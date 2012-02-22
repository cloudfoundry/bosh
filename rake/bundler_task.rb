# Copyright (c) 2009-2012 VMware, Inc.

require "rake/tasklib"

# HACK to get a clean ENV from Bundler. (already in Bundler 1.1+)
if Gem::Version.new(Bundler::VERSION) < Gem::Version.new("1.1.0")
  module Bundler
    class << self
      def with_original_env
        bundled_env = ENV.to_hash
        ENV.replace(ORIGINAL_ENV)
        yield
      ensure
        ENV.replace(bundled_env.to_hash)
      end

      def with_clean_env
        with_original_env do
          ENV.delete_if { |k, _| k[0, 7] == "BUNDLE_" }
          if ENV.has_key?("RUBYOPT")
            ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
          end
          yield
        end
      end
    end
  end
end

class BundlerTask < ::Rake::TaskLib
  def initialize
    namespace "bundler" do
      desc "Install gems"
      task "install" do
        Bundler.with_clean_env do
          sh("bundle install")
        end
      end

      environments = %w(test development production)

      environments.each do |env|
        desc "Install gems for #{env}"
        task "install:#{env}" do
          Bundler.with_clean_env do
            sh("bundle install --without #{(environments - [env]).join(" ")}")
          end
        end
      end
    end
  end
end
