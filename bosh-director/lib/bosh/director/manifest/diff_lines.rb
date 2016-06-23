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
      vm_extensions
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
      addons
    )

    def order
      sections = {}
      key = nil

      self.each do |line|
        if line.indent == 0 && line.text !~ /^[ -]/
          key = line.text
          sections[key] = []
          sections[key] << Line.new(0, '', nil)
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

      # ignore the empty line before the first section
      ordered_lines.shift
      self.replace(ordered_lines)
    end
  end
end
