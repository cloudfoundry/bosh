# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class DeploymentManifestCompiler
    attr_accessor :properties

    def initialize(raw_manifest)
      @raw_manifest = raw_manifest
      @properties = {}
    end

    def property(name)
      @properties[name] || raise(UndefinedProperty,
                                 "Cannot resolve deployment property `#{name}'")
    end

    def result
      # TODO: erb is just a fancy eval, so it's not very trustworthy,
      # consider using more constrained template engine.
      # Note that we use $SAFE=4 for ERB which is a strawman sandbox.
      ERB.new(@raw_manifest, 4).result(binding.taint)
    rescue SyntaxError => e
      raise MalformedManifest,
            "Deployment manifest contains a syntax error\n" + e.to_s
    end
  end

end
