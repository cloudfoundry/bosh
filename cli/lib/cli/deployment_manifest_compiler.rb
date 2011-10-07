module Bosh::Cli

  class DeploymentManifestCompiler

    class ManifestError < StandardError; end
    class UndefinedProperty < ManifestError; end
    class MalformedManifest < ManifestError; end

    attr_accessor :deployment_properties
    attr_accessor :release_properties

    def initialize(raw_manifest)
      @raw_manifest = raw_manifest
      @deployment_properties = {}
      @release_properties = {}
    end

    def release_property(name)
      @release_properties[name] || raise(UndefinedProperty, "Cannot resolve release property `#{name}'")
    end

    def deployment_property(name)
      @deployment_properties[name] || raise(UndefinedProperty, "Cannot resolve deployment property `#{name}'")
    end

    def result
      # TODO: erb is just a fancy eval, so it's not very trustworthy,
      # consider using more constrained template engine.
      # Note that we use $SAFE=4 for ERB which is a strawman sandbox.
      ERB.new(@raw_manifest, 4).result(binding.taint)
    rescue SyntaxError => e
      raise MalformedManifest, "Deployment manifest contains a syntax error\n" + e.to_s
    end
  end

end
