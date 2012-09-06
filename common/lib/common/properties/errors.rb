# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Common

  class TemplateEvaluationFailed < StandardError; end

  class UnknownProperty < StandardError
    attr_reader :name

    def initialize(name)
      @name = name
      super("Can't find property `#{name}'")
    end
  end

end
