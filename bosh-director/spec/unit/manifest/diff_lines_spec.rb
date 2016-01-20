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

    describe 'redact_properties' do
      context 'when lines contain properties' do
        before do
          diff_lines << Line.new(0, 'azs:', nil)
          diff_lines << Line.new(0, '- name: z1', nil)
          diff_lines << Line.new(0, '  cloud_properties:', nil)
          diff_lines << Line.new(0, '    availability_zone: us-east-1', nil)
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, '- name: job1', nil)
          diff_lines << Line.new(0, '  properties:', nil)
          diff_lines << Line.new(2, 'foo: bar', nil)
          diff_lines << Line.new(2, 'baz: qux', nil)
          diff_lines << Line.new(0, '- name: job2', nil)
          diff_lines << Line.new(1, 'properties:', nil)
          diff_lines << Line.new(2, 'baz: qux', nil)
          diff_lines << Line.new(2, 'foo: bar', nil)
        end

        it 'redacts all leaf node values' do
          expect(diff_lines.map(&:to_s)).to eq([
            'azs:',
            '- name: z1',
            '  cloud_properties:',
            '    availability_zone: us-east-1',
            'jobs:',
            '- name: job1',
            '  properties:',
            '    foo: bar',
            '    baz: qux',
            '- name: job2',
            '  properties:',
            '    baz: qux',
            '    foo: bar',
          ])

          diff_lines.redact_properties

          expect(diff_lines.map(&:to_s)).to eq([
            'azs:',
            '- name: z1',
            '  cloud_properties:',
            '    availability_zone: us-east-1',
            'jobs:',
            '- name: job1',
            '  properties:',
            '    foo: <redacted>',
            '    baz: <redacted>',
            '- name: job2',
            '  properties:',
            '    baz: <redacted>',
            '    foo: <redacted>',
          ])
        end
      end

      context 'when properties contain arrays' do
        before do
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, '- name: job1', nil)
          diff_lines << Line.new(0, '  properties:', nil)
          diff_lines << Line.new(0, '    foo:', nil)
          diff_lines << Line.new(0, '    - bar', nil)
          diff_lines << Line.new(0, '    - baz', nil)
          diff_lines << Line.new(0, '    elems:', nil)
          diff_lines << Line.new(0, '    - name: foo', nil)
          diff_lines << Line.new(0, '- name: job2', nil)
          diff_lines << Line.new(1, 'properties:', nil)
          diff_lines << Line.new(2, 'foo:', nil)
          diff_lines << Line.new(2, '- bar', nil)
          diff_lines << Line.new(2, '- baz', nil)
          diff_lines << Line.new(0, '- name: job3', nil)
          diff_lines << Line.new(0, '  properties:', nil)
          diff_lines << Line.new(0, '    foo: [1, 2]', nil)
        end

        it 'redacts array values' do

          expect(diff_lines.map(&:to_s)).to eq([
           'jobs:',
           '- name: job1',
           '  properties:',
           '    foo:',
           '    - bar',
           '    - baz',
           '    elems:',
           '    - name: foo',
           '- name: job2',
           '  properties:',
           '    foo:',
           '    - bar',
           '    - baz',
           '- name: job3',
           '  properties:',
           '    foo: [1, 2]',
          ])

          diff_lines.redact_properties

          expect(diff_lines.map(&:to_s)).to eq([
           'jobs:',
           '- name: job1',
           '  properties:',
           '    foo:',
           '    - <redacted>',
           '    - <redacted>',
           '    elems:',
           '    - name: <redacted>',
           '- name: job2',
           '  properties:',
           '    foo:',
           '    - <redacted>',
           '    - <redacted>',
           '- name: job3',
           '  properties:',
           '    foo: <redacted>',
         ])

        end
      end

      context 'when diff contains env information' do
        before do
          diff_lines << Line.new(0, 'resource_pools:', nil)
          diff_lines << Line.new(0, '- name: foo', nil)
          diff_lines << Line.new(1, 'env:', nil)
          diff_lines << Line.new(2, 'user: foo', nil)
          diff_lines << Line.new(2, 'password: bar', nil)
          diff_lines << Line.new(0, 'jobs:', nil)
          diff_lines << Line.new(0, '- name: job1', nil)
          diff_lines << Line.new(0, '  env:', nil)
          diff_lines << Line.new(0, '    bosh:', nil)
          diff_lines << Line.new(0, '      password: foobar', nil)
        end

        it 'redacts all env values' do
          expect(diff_lines.map(&:to_s)).to eq([
                'resource_pools:',
                '- name: foo',
                '  env:',
                '    user: foo',
                '    password: bar',
                'jobs:',
                '- name: job1',
                '  env:',
                '    bosh:',
                '      password: foobar',
              ])

          diff_lines.redact_properties

          expect(diff_lines.map(&:to_s)).to eq([
                'resource_pools:',
                '- name: foo',
                '  env:',
                '    user: <redacted>',
                '    password: <redacted>',
                'jobs:',
                '- name: job1',
                '  env:',
                '    bosh:',
                '      password: <redacted>',
              ])
        end
      end
    end
  end
end
