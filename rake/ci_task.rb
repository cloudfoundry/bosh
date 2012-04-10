# Copyright (c) 2009-2012 VMware, Inc.

require "pathname"
require "rake/tasklib"

class CiTask < ::Rake::TaskLib
  attr_accessor :rspec_task
  attr_accessor :test_reports_dir
  attr_accessor :coverage_dir
  attr_accessor :root_dir

  def initialize
    yield self

    @root_dir ||= Dir.pwd
    @test_reports_dir ||= File.join(@root_dir, "ci_result/reports")
    @coverage_dir ||= File.join(@root_dir, "ci_result/coverage")

    # TODO remove once CI is reconfigured
    legacy_spec_coverage = File.join(@root_dir, "spec_coverage")
    legacy_spec_reports = File.join(@root_dir, "spec_reports")

    actual_rspec_task = Rake.application.lookup(@rspec_task.name)
    rspec_task_description = actual_rspec_task.comment

    if rspec_task_description && !rspec_task_description.empty?
      desc("#{rspec_task_description} for CIs")
    end
    task("#{@rspec_task.name}:ci") do |task|
      rm_rf(legacy_spec_coverage)
      rm_rf(legacy_spec_reports)

      rm_rf(@test_reports_dir)
      rm_rf(@coverage_dir)

      require "ci/reporter/rake/rspec"
      ENV["CI_REPORTS"] = @test_reports_dir
      Rake::Task["ci:setup:rspec"].execute

      if RUBY_VERSION < "1.9"
        @rspec_task.rcov = true
        @rspec_task.rcov_opts =
            %W{--exclude spec\/,vendor\/ -o "#{@coverage_dir}/rcov"}
        actual_rspec_task.invoke
      else
        simple_cov_helper = File.expand_path("../simplecov_helper", __FILE__)
        ENV["SPEC_OPTS"] = "#{ENV['SPEC_OPTS']} --require #{simple_cov_helper}"
        ENV["SIMPLECOV"] = "1"
        ENV["SIMPLECOV_ROOT"] = @root_dir
        ENV["SIMPLECOV_EXCLUDE"] = "spec, vendor"
        ENV["SIMPLECOV_DIR"] = Pathname.new(@coverage_dir).relative_path_from(
            Pathname.new(root_dir)).to_s
        actual_rspec_task.invoke
      end

      ln_s(@test_reports_dir, legacy_spec_reports)
      ln_s(@coverage_dir, legacy_spec_coverage)
puts `ls -ltr #{legacy_spec_reports}`
puts `ls -ltr #{legacy_spec_coverage}`
puts `ls -ltrR ci_result`
    end
  end
end
