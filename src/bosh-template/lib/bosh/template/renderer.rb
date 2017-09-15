require 'erb'
require 'json'
require 'bosh/template/evaluation_context'

module Bosh
  module Template
    class Renderer
      def initialize(options={})
        @context = options.fetch(:context)
      end

      def render(template_name)
        spec = JSON.parse(@context)
        evaluation_context = EvaluationContext.new(spec, nil)
        template = ERB.new(File.read(template_name), safe_level = nil, trim_mode = "-")
        template.result(evaluation_context.get_binding)
      end
    end
  end
end
