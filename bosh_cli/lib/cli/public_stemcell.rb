module Bosh::Cli
  class PublicStemcell
    attr_reader :name

    def initialize(name, properties)
      @name = name
      @properties = properties
    end

    def url
      @properties['url']
    end

    def size
      @properties['size']
    end

    def sha1
      @properties['sha1']
    end

    def tags
      @properties['tags']
    end

    def tag_names
      tags ? tags.join(', ') : ''
    end

    def tagged?(requested_tags)
      tags.nil? || (requested_tags - tags).empty?
    end
  end
end
