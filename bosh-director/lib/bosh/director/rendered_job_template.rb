module Bosh::Director
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
      templates.keys.sort.each do |src_name|
        template_digest << templates[src_name]
      end

      template_digest.hexdigest
    end
  end
end
