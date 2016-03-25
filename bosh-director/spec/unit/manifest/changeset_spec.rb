require 'spec_helper'

module Bosh::Director
  describe Changeset do
    subject(:changeset) do
      changeset = described_class.new(old, new)
      changeset.diff.map { |l| [l.to_s, l.status] }
    end

    let(:old) do
      {
        'azs' => [
          {
            'name' => 'z1',
            'cloud_properties' => {
              'datacenters' => [
                {'name' => 'dc1'},
                {'name' => 'dc2'},
              ]
            }
          }
        ]
      }
    end

    context 'when old and new are the same' do
      let(:new) { old }

      it 'returns no changes' do
        described_class.new({'foo'=>['bar']}, {'foo'=>['bar']}).diff.order
      end
    end

    context 'when array elements order changed' do
      let(:new) do
        {
          'azs' => [
            {
              'name' => 'z1',
              'cloud_properties' => {
                'datacenters' => [
                  {'name' => 'dc2'},
                  {'name' => 'dc1'},
                ]
              }
            }
          ]
        }
      end

      it 'returns no changes' do
        expect(changeset).to be_empty
      end
    end

    context 'when property was added' do
      context 'when leaf property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2', 'location' => 'Tashkent'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns change based by name and includes name' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - name: dc2', nil],
            ['      location: Tashkent', 'added'],
          ])
        end
      end

      context 'when leaf property without name' do
        let(:new) do
          {
            'azs' => [
              {
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'location' => 'Tashkent'},
                  ]
                }
              }
            ]
          }
        end

        it 'treats them as separate changes' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- cloud_properties:', 'added'],
            ['    datacenters:', 'added'],
            ['    - name: dc1', 'added'],
            ['    - location: Tashkent', 'added'],
            ['- name: z1', 'removed'],
            ['  cloud_properties:', 'removed'],
            ['    datacenters:', 'removed'],
            ['    - name: dc1', 'removed'],
            ['    - name: dc2', 'removed'],
          ])
        end
      end

      context 'when middle property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'release' => 'test-release',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end

        it 'treats them as separate changes' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  release: test-release', 'added']
          ])
        end
      end

      context 'when property added to array' do
        let(:old) do
          {
            'azs' => ['az1', 'az2']
          }
        end
        let(:new) do
          {
            'azs' => ['az1', 'az2', 'az3']
          }
        end
        it 'returns added property' do
          expect(changeset).to eq([
                                    ['azs:', nil],
                                    ['- az3', 'added']
                                  ])
        end
      end
    end

    context 'when array element was added' do
      context 'when leaf property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                    {'name' => 'dc3'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns added change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - name: dc3', 'added']
          ])
        end
      end

      context 'when middle property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              },
              {
                'name' => 'z2',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns added change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z2', 'added'],
            ['  cloud_properties:', 'added'],
            ['    datacenters:', 'added'],
            ['    - name: dc2', 'added'],
          ])
        end
      end

      context 'when array was added' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    ['dc1', 'dc2']
                  ]
                }
              }
            ]
          }
        end
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    ['dc1', 'dc2'], ['dc3', 'dc4'], ['dc5'], ['dc6']
                  ]
                }
              }
            ]
          }
        end
        it 'returns added property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - - dc3', 'added'],
            ['      - dc4', 'added'],
            ['    - - dc5', 'added'],
            ['    - - dc6', 'added'],
          ])
        end
      end
    end

    context 'when property was removed' do
      context 'when leaf property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns added change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - name: dc2', 'removed']
          ])
        end
      end

      context 'when middle property' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'release' => 'test-release',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                  ]
                }
              }
            ]
          }
        end
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1'
              }
            ]
          }
        end
        it 'returns added change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  release: test-release', 'removed'],
            ['  cloud_properties:', 'removed'],
            ['    datacenters:', 'removed'],
            ['    - name: dc1', 'removed'],
          ])
        end
      end

      context 'when property removed from array' do
        let(:old) do
          {
            'azs' => ['az1', 'az2', 'az3']
          }
        end
        let(:new) do
          {
            'azs' => ['az1', 'az2']
          }
        end
        it 'returns added property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- az3', 'removed']
          ])
        end
      end
    end

    context 'when array element was removed' do
      context 'when leaf property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns removed change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - name: dc2', 'removed'],
          ])
        end

        context 'when leaf property is string' do
          let(:old) do
            {
              'networks' => [
                {
                  'name' => 'default',
                  'default' => ['dns', 'gateway']
                }
              ]
            }
          end
          let(:new) do
            {
              'networks' => [
                {
                  'name' => 'default',
                  'default' => ['dns']
                }
              ]
            }
          end

          it 'returns removed change' do
            expect(changeset).to eq([
              ['networks:', nil],
              ['- name: default', nil],
              ['  default:', nil],
              ['  - gateway', 'removed'],
            ])
          end
        end
      end

      context 'when middle property' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                  ]
                }
              },
              {
                'name' => 'z2',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z2',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns added change' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', 'removed'],
            ['  cloud_properties:', 'removed'],
            ['    datacenters:', 'removed'],
            ['    - name: dc1', 'removed'],
          ])
        end
      end

      context 'when array was removed' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    ['dc1', 'dc2'], ['dc3', 'dc4'], ['dc5'], ['dc6']
                  ]
                }
              }
            ]
          }
        end
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    ['dc1', 'dc2']
                  ]
                }
              }
            ]
          }
        end
        it 'returns added property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - - dc3', 'removed'],
            ['      - dc4', 'removed'],
            ['    - - dc5', 'removed'],
            ['    - - dc6', 'removed'],
          ])
        end
      end
    end

    context 'when property was changed' do
      context 'when leaf property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc3'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns changed property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - name: dc3', 'added'],
            ['    - name: dc2', 'removed'],
          ])
        end
      end

      context 'when middle property' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'iaas_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end

        it 'returns changed property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', 'removed'],
            ['    datacenters:', 'removed'],
            ['    - name: dc1', 'removed'],
            ['    - name: dc2', 'removed'],
            ['  iaas_properties:', 'added'],
            ['    datacenters:', 'added'],
            ['    - name: dc1', 'added'],
            ['    - name: dc2', 'added'],
          ])
        end
      end

      context 'when name changes' do
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z2',
                'cloud_properties' => {
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end
        it 'assumes the node has been removed and a new one (with the new name) has been added' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z2', 'added'],
            ['  cloud_properties:', 'added'],
            ['    datacenters:', 'added'],
            ['    - name: dc1', 'added'],
            ['    - name: dc2', 'added'],
            ['- name: z1', 'removed'],
            ['  cloud_properties:', 'removed'],
            ['    datacenters:', 'removed'],
            ['    - name: dc1', 'removed'],
            ['    - name: dc2', 'removed']
          ])
        end
      end

      context 'when property (that is not a Hash or Array) changes' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'location' => 'Tashkent',
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end
        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'location' => 'Delhi',
                  'datacenters' => [
                    {'name' => 'dc1'},
                    {'name' => 'dc2'},
                  ]
                }
              }
            ]
          }
        end
        it 'returns changed property' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    location: Tashkent', 'removed'],
            ['    location: Delhi', 'added'],
          ])
        end
      end

      context 'when in array changes' do
        let(:old) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    'dc1', 'dc2'
                  ],
                }
              }
            ]
          }
        end

        let(:new) do
          {
            'azs' => [
              {
                'name' => 'z1',
                'cloud_properties' => {
                  'datacenters' => [
                    'dc3', 'dc2'
                  ],
                }
              }
            ]
          }
        end
        it 'shows changed property as added and removed' do
          expect(changeset).to eq([
            ['azs:', nil],
            ['- name: z1', nil],
            ['  cloud_properties:', nil],
            ['    datacenters:', nil],
            ['    - dc3', 'added'],
            ['    - dc1', 'removed'],
          ])
        end
      end
    end

    context 'subnet ranges' do
      let(:old) do
        {
          'networks' => [
            {
              'name' => 'default',
              'subnets' => [
                {
                  'range' => '10.10.10.0/24',
                  'reserved' => ['10.10.10.11']
                }
              ]
            }
          ]
        }
      end

      let(:new) do
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
          ]
        }
      end

      it 'treats subnets with the same range as equivalent' do
        expect(changeset).to eq([
          ['networks:', nil],
          ['- name: default', nil],
          ['  subnets:', nil],
          ['  - range: 10.10.10.0/24', nil],
          ['    reserved:', nil],
          ['    - 10.10.10.15', 'added'],
          ['    - 10.10.10.11', 'removed'],
        ])
      end
    end

    context 'redact properties/env' do
      it 'redacts child nodes of properties/env hashes recursively' do
        manifest_obj = {
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
                'c' => 'redact-me',
                'e' => 'i-am-secret'
              }
            }
          ]
        }

        expect(described_class.redact_properties!(manifest_obj)).to eq({
          'name' => 'test_name',
          'uuid' => '12324234234234234234',
          'env' => {
              'bosh' => {
                  'one' => ['<redacted>', '<redacted>', {'three' => '<redacted>'}],
                  'two' => '<redacted>',
                  'three' => '<redacted>'
              },
              'c' => 'dont-redact-me',
              'e' => 'i-am-not-secret'
          },
          'jobs' => [
            {
              'name' => "test_job",
              'properties' => {
                'a' => {
                  'one' => ['<redacted>', '<redacted>', {'three' => '<redacted>'}],
                  'two' => '<redacted>',
                  'three' => '<redacted>'
                },
                'c' => '<redacted>',
                'e' => '<redacted>'
              }
            }
          ]
        })
      end

      context 'when properties are present at both local and global level' do
        it 'redacts properties at both levels' do
          manifest_obj = {
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

          expect(described_class.redact_properties!(manifest_obj)).to eq({
                'jobs' => [
                  {
                    'name' => "test_job",
                    'properties' => {
                      'a' => {
                        'one' => ['<redacted>', '<redacted>', {'three' => '<redacted>'}],
                        'two' => '<redacted>',
                        'three' => '<redacted>'
                      },
                      'c' => '<redacted>',
                      'e' => '<redacted>'
                    }
                  }
                ],
                'properties' => {
                  'x' => {
                    'x-one' => ['<redacted>', '<redacted>', {'x-three' => '<redacted>'}],
                    'x-two' => '<redacted>',
                    'x-three' => '<redacted>'
                  },
                  'y' => '<redacted>',
                  'z' => '<redacted>'
                }
              })
        end
      end

      it 'does not redact if properties/env is not a hash' do
        manifest_obj = {
          'name' => 'test_name',
          'uuid' => '12324234234234234234',
          'env' => 'hello',
          'jobs' => [
            {
              'name' => 'test_job',
              'properties' => [
                'a',
                'b',
                'c'
              ]
            }
          ]
        }

        expect(described_class.redact_properties!(manifest_obj)).to eq(manifest_obj)
      end
    end

    context 'property was an array, but is now a hash' do
      let(:old) do
        {
          'stuff' => {
            'things' => ['apples', 'oranges', 'bananas']
          }
        }
      end

      let(:new) do
        {
          'stuff' => {
            'things' => {
              'cheese' => 123,
              'wine' => 456
            }
          }
        }
      end

      it 'treats subnets with the same range as equivalent' do
        expect(changeset).to eq([
              ['stuff:', nil],
              ['  things:', 'removed'],
              ['  - apples', 'removed'],
              ['  - oranges', 'removed'],
              ['  - bananas', 'removed'],
              ['  things:', 'added'],
              ['    cheese: 123', 'added'],
              ['    wine: 456', 'added'],
            ])
      end
    end

    context 'property was an integer, but is now a hash' do
      let(:old) do
        {
          'stuff' => {
            'things' => 3
          }
        }
      end

      let(:new) do
        {
          'stuff' => {
            'things' => {
              'cheese' => 123,
              'wine' => 456
            }
          }
        }
      end

      it 'treats subnets with the same range as equivalent' do
        expect(changeset).to eq([
              ['stuff:', nil],
              ['  things: 3', 'removed'],
              ['  things:', 'added'],
              ['    cheese: 123', 'added'],
              ['    wine: 456', 'added'],
            ])
      end
    end

    context 'property was a string, but is now a hash' do
      let(:old) do
        {
          'stuff' => {
            'things' => 'three'
          }
        }
      end

      let(:new) do
        {
          'stuff' => {
            'things' => {
              'cheese' => 123,
              'wine' => 456
            }
          }
        }
      end

      it 'treats subnets with the same range as equivalent' do
        expect(changeset).to eq([
              ['stuff:', nil],
              ['  things: three', 'removed'],
              ['  things:', 'added'],
              ['    cheese: 123', 'added'],
              ['    wine: 456', 'added'],
            ])
      end
    end
  end
end
