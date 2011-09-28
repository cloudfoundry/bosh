$:.unshift(File.dirname(__FILE__))

require "simplecov-clover/version"
require "builder"

module SimpleCov
  module Formatter
    class CloverFormatter

      def self.output_path
        File.join(SimpleCov.coverage_path, "/clover.xml")
      end

      def format(result)

        builder = Builder::XmlMarkup.new(:indent => 2)
        xml = builder.coverage(:generated => Time.now.to_i) do |coverage|
          coverage.project(:timestamp => Time.now.to_i) do |project|
            project_total = 0
            project_covered = 0

            result.files.each do |source_file|
              project.file(:name => source_file.filename) do |file|
                total = source_file.lines.select { |line| line.covered? || line.missed? }.count
                covered = source_file.covered_lines.count

                source_file.lines.each_with_index do |line, i|
                  next if line.never?
                  file.line(:num => i + 1, :type => "stmt", :count => line.coverage)
                end

                project_total += total
                project_covered += covered

                file_metrics = {
                  :ncloc => total,
                  :loc => source_file.lines.count,
                  :classes => 0,
                  :methods => 0,
                  :coveredmethods => 0,
                  :conditionals => 0,
                  :coveredconditionals => 0,
                  :elements => total,
                  :coveredelements => covered,
                  :statements => total,
                  :coveredstatements => covered
                }

                file.metrics(file_metrics)
              end
            end

            project_metrics = {
              :files => result.files.size,
              :ncloc => result.total_lines,
              :loc => result.files.inject(0) {|total, file| total += file.lines.count },
              :classes => 0,
              :methods => 0,
              :coveredmethods => 0,
              :elements => project_total,
              :coveredelements => project_covered,
              :statements => project_total,
              :coveredstatements => project_covered
            }

            project.metrics(project_metrics)
          end
        end

        File.open(SimpleCov::Formatter::CloverFormatter.output_path, "w" ) do |f|
          f.write(xml)
        end
      end
    end
  end
end
