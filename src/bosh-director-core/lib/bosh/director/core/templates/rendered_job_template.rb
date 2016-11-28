require 'bosh/director/core/templates'

module Bosh::Director::Core::Templates
  class RenderedJobTemplate
    attr_reader :name, :monit, :templates

    def initialize(name, monit, templates)
      @name = name
      @monit = monit
      @templates = templates
    end

    def template_hash
      template_digest = Digest::SHA1.new
      template_digest << monit
      templates.sort { |x, y| x.src_name <=> y.src_name }.each do |template_file|
        template_digest << template_file.contents
      end

      template_digest.hexdigest
    end
  end
end
