require 'spec_helper'

module Bosh::Director
  describe Redactor do
    let(:manifest_obj) do
      {
        'name' => 'test_name',
        'uuid' => '12324234234234234234',
        'env' => {
          'bosh' => {
            'one' => [1, 2, {'three' => 3}],
            'two' => 2,
            'three' => 3
          },
          'c' => 'dont-redact-me',
          'e' => 'i-am-not-secret'
        },
        'jobs' => [
          {
            'name' => "test_job",
            'properties' => {
              'a' => {
                'one' => [1, 2, {'three' => 3}],
                'two' => 2,
                'three' => 3
              },
              'c' => "redact-me",
              'e' => 'i-am-secret'
            }
          }
        ]
      }
    end

    let(:manifest_with_redaction_markers) do
      {
        'name' => 'test_name',
        'uuid' => '12324234234234234234',
        'env' => {
          'bosh' => {
            'one' => ["1<redact this!!!>", "2<redact this!!!>", {'three' => "3<redact this!!!>"}],
            'two' => "2<redact this!!!>",
            'three' => "3<redact this!!!>"
          },
          'c' => 'dont-redact-me',
          'e' => 'i-am-not-secret'
        },
        'jobs' => [
          {
            'name' => "test_job",
            'properties' => {
              'a' => {
                'one' => ["1<redact this!!!>", "2<redact this!!!>", {'three' => "3<redact this!!!>"}],
                'two' => "2<redact this!!!>",
                'three' => "3<redact this!!!>"
              },
              'c' => 'redact-me<redact this!!!>',
              'e' => 'i-am-secret<redact this!!!>'
            }
          }
        ]
      }
    end

    let (:marked_for_redaction){ Redactor.mark_properties_for_redaction(manifest_obj) }
    let (:diffy) { Changeset.new(manifest_obj, manifest_with_redaction_markers).diff }
    let(:redacted_diff){ Redactor.redact_difflines_marked_for_redaction(diffy)}

    describe '#mark_properties_for_redaction' do
      it "marks appropriate fields in a manifest hash for redaction" do
        expect(marked_for_redaction.to_yaml).to eq manifest_with_redaction_markers.to_yaml
      end
    end

    describe '#redact_difflines_marked_for_redaction' do
      let(:diff) do
        Changeset.new(
          Redactor.mark_properties_for_redaction(old_manifest),
          Redactor.mark_properties_for_redaction(new_manifest)
        ).diff
      end

      let(:redacted_diff) do
        Redactor.redact_difflines_marked_for_redaction(diff)
      end

      let(:redacted_diff_arrays) do
        redacted_diff.map { |l| [l.to_s, l.status] }
      end

      context 'todo' do
        let(:old_manifest) do
          {
            'networks' => [
              {
                'name' => 'default',
                'subnets' => [
                  {
                    'range' => '10.10.10.0/24',
                    'reserved' => ['10.10.10.15']
                  },
                  {
                    'range' => '10.10.11.0/24',
                    'reserved' => ['10.10.11.15']
                  }
                ]
              }
            ],
            'properties' => {
              'before' => 'value',
            }
          }
        end

        let (:new_manifest) do
          {
            'networks' => [
              {
                'name' => 'default',
                'subnets' => [
                  {
                    'range' => '10.10.10.0/24',
                    'reserved' => ['10.10.10.15']
                  }
                ]
              }
            ],
            'properties' => {
              'blurp' => [ 1, true, 'blahblah'],
              'adsf' => { 'something' => nil}
            }
          }
        end

        it 'redacts a diff' do
          expect(redacted_diff_arrays).to eq([
            ['networks:', nil],
            ['- name: default', nil],
            ['  subnets:', nil],
            ['  - range: 10.10.11.0/24', 'removed'],
            ['    reserved:', 'removed'],
            ['    - 10.10.11.15', 'removed'],
            ['properties:', nil],
            ['  before: <redacted>', 'removed'],
            ['  blurp:', 'added'],
            ['  - <redacted>', 'added'],
            ['  - <redacted>', 'added'],
            ['  - <redacted>', 'added'],
            ['  adsf:', 'added'],
            ['    something: <redacted>', 'added'],
          ])
        end

      end

    end



    context 'redact properties/env' do
      it 'redacts child nodes of properties/bosh hashes recursively' do
        expect(described_class.mark_properties_for_redaction(manifest_obj)).to eq(
          {
            'name' => 'test_name',
            'uuid' => '12324234234234234234',
            'env' => {
              'bosh' => {
                'one' => ['1<redact this!!!>', '2<redact this!!!>', {'three' => '3<redact this!!!>'}],
                'two' => '2<redact this!!!>',
                'three' => '3<redact this!!!>'
              },
              'c' => 'dont-redact-me',
              'e' => 'i-am-not-secret'
            },
            'jobs' => [
              {
                'name' => "test_job",
                'properties' => {
                  'a' => {
                    'one' => ['1<redact this!!!>', '2<redact this!!!>', {'three' => '3<redact this!!!>'}],
                    'two' => '2<redact this!!!>',
                    'three' => '3<redact this!!!>'
                  },
                  'c' => "redact-me<redact this!!!>",
                  'e' => 'i-am-secret<redact this!!!>'
                }
              }
            ]
          }
        )
      end

      context 'when properties are present at both local and global level' do
        let (:manifest_obj) do
          {
            'jobs' => [
              {
                'name' => "test_job",
                'properties' => {
                  'a' => {
                    'one' => [1, 2, {'three' => 3}],
                    'two' => 2,
                    'three' => 3
                  },
                  'c' => 'redact-me',
                  'e' => 'i-am-secret'
                }
              }
            ],
              'properties' => {
              'x' => {
                'x-one' => ['x1', 'x2', {'x-three' => 'x3'}],
                'x-two' => 'x2',
                'x-three' => 'x3'
              },
              'y' => 'y-redact-me',
              'z' => 'z-secret'
            }
          }
        end

        it 'redacts properties at both levels' do
          expect(described_class.mark_properties_for_redaction(manifest_obj)).to eq(
            {
              'jobs' => [
                {
                  'name' => "test_job",
                  'properties' => {
                    'a' => {
                      'one' => ['1<redact this!!!>', '2<redact this!!!>', {'three' => '3<redact this!!!>'}],
                      'two' => '2<redact this!!!>',
                      'three' => '3<redact this!!!>'
                    },
                    'c' => 'redact-me<redact this!!!>',
                    'e' => 'i-am-secret<redact this!!!>'
                  }
                }
              ],
              'properties' => {
                'x' => {
                  'x-one' => ['x1<redact this!!!>', 'x2<redact this!!!>', {'x-three' => 'x3<redact this!!!>'}],
                  'x-two' => 'x2<redact this!!!>',
                  'x-three' => 'x3<redact this!!!>'
                },
                'y' => 'y-redact-me<redact this!!!>',
                'z' => 'z-secret<redact this!!!>'
              }
            }
          )
        end
      end
    end
  end
end
