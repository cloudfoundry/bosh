require 'spec_helper'

module Bosh::Director
  describe DiffLines do
    subject(:diff_lines) { described_class.new }

    describe 'order' do
      context 'when simple' do
        before do
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, 'azs:', nil)
        end

        it 're-orders lines based on desired manifest keys order' do
          expect(diff_lines.map(&:to_s)).to eq([
            'jobs:',
            'azs:',
          ])
          diff_lines.order
          expect(diff_lines.map(&:to_s)).to eq([
            'azs:',
            'jobs:',
          ])
        end
      end

      context 'when indented' do
        before do
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, '- name: job1', nil)
          diff_lines << Line.new(0, '  properties:', nil)
          diff_lines << Line.new(2, 'foo: bar', nil)
          diff_lines << Line.new(0, 'azs:', nil)
          diff_lines << Line.new(0, '- name: z1', nil)
          diff_lines << Line.new(1, 'cloud_properties:', nil)
          diff_lines << Line.new(2, 'baz: qux', nil)
        end

        it 're-orders lines based on desired manifest keys order' do
          expect(diff_lines.map(&:to_s)).to eq([
            'jobs:',
            '- name: job1',
            '  properties:',
            '    foo: bar',
            'azs:',
            '- name: z1',
            '  cloud_properties:',
            '    baz: qux',
          ])
          diff_lines.order
          expect(diff_lines.map(&:to_s)).to eq([
            'azs:',
            '- name: z1',
            '  cloud_properties:',
            '    baz: qux',
            'jobs:',
            '- name: job1',
            '  properties:',
            '    foo: bar',
          ])
        end
      end

      context 'when extra sections defined' do
        before do
          diff_lines << Line.new(0, 'foo:', nil)
          diff_lines << Line.new(0, '  bar: baz', nil)
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, 'azs:', nil)
        end

        it 're-orders lines based on desired manifest keys order' do
          expect(diff_lines.map(&:to_s)).to eq([
             'foo:',
             '  bar: baz',
             'jobs:',
             'azs:',
          ])
          diff_lines.order
          expect(diff_lines.map(&:to_s)).to eq([
            'azs:',
            'jobs:',
            'foo:',
            '  bar: baz',
          ])
        end
      end
    end
  end
end
