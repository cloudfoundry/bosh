# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  class FileMatcher
    attr_writer :globs

    def initialize(base_dir)
      @base_dir = base_dir
    end

    def base_dir
      @base_dir
    end

    def globs
      @globs || default_globs
    end

    def default_globs
      []
    end
  end

  class AgentLogMatcher < FileMatcher
    def base_dir
      File.join(@base_dir, "bosh", "log")
    end

    def default_globs
      [ "**/*" ]
    end
  end

  class JobLogMatcher < FileMatcher
    def base_dir
      File.join(@base_dir, "sys", "log")
    end

    def default_globs
      [ "**/*.log" ]
    end
  end

end
