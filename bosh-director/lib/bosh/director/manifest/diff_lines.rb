module Bosh::Director
  class Line < Struct.new(:indent, :text, :status)
    INDENT = 2

    def to_s
      "#{' ' * INDENT * indent}#{text}"
    end

    def full_indent
      indent + text[/^ */].size / INDENT
    end
  end

  class DiffLines < Array
    MANIFEST_KEYS_ORDER = %w(
      azs
      vm_types
      resource_pools
      compilation
      networks
      disk_types
      disk_pools
      name
      director_uuid
      stemcells
      releases
      update
      jobs
    )

    REDACT_KEY_NAMES = %w(
      properties
      env
    )

    def order
      sections = {}
      key = nil

      self.each do |line|
        if line.indent == 0 && line.text !~ /^[ -]/
          key = line.text
          sections[key] = []
        end

        sections[key] << line
      end

      ordered_lines = []
      MANIFEST_KEYS_ORDER.each do |manifest_key|
        section_name = manifest_key + ':'
        lines = sections[section_name]
        ordered_lines += lines.to_a
        sections.delete(section_name)
      end

      sections.each do |_, section_lines|
        section_lines.each do |line|
          ordered_lines << line
        end
      end

      self.replace(ordered_lines)
    end

    def redact_properties
      i = 0
      while i < self.size
        line = self[i]

        if REDACT_KEY_NAMES.any? { |key_name| line.text =~ /\b#{key_name}:/ }
          properties_indent = line.full_indent
          i += 1
          line = self[i]

          while line && line.full_indent > properties_indent
            line.text.gsub!(/: .+/, ': <redacted>') # readact hash values
            line.text.gsub!(/- [^:]+$/, '- <redacted>') # redact array values
            i += 1
            line = self[i]
          end
        end
        i += 1
      end
      self
    end
  end
end
