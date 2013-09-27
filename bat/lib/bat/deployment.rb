require 'erb'
require 'tempfile'
require 'yaml'

module Bosh; end # Ugly hack
require 'common/properties'

module Bat
  class Deployment
    def initialize(spec)
      @spec = spec
      generate_deployment_manifest(spec)
    end

    def name
      yaml['name']
    end

    def to_path
      path
    end

    def delete
      puts "<-- rm #{path}"
      FileUtils.rm_rf(File.dirname(to_path)) unless keep?
    end

    def generate_deployment_manifest(spec)
      @context = Bosh::Common::TemplateEvaluationContext.new(spec)
      erb = ERB.new(load_template(@context.spec.cpi))
      result = erb.result(@context.get_binding)
      puts result
      @yaml = YAML.load(result)
      store_manifest(result)
    end

    private

    attr_reader :path, :yaml

    def store_manifest(content)
      manifest = tempfile('deployment')
      manifest.write(content)
      manifest.close
      @path = manifest.path
    end

    def load_template(cpi)
      template = File.expand_path("../../../templates/#{cpi}.yml.erb", __FILE__)
      File.read(template)
    end

    def tempfile(name)
      File.open(File.join(Dir.mktmpdir, name), 'w')
    end

    def keep?
      ENV['BAT_MANIFEST'] == 'keep'
    end
  end
end
