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
        expect(changeset).to be_empty
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
    end
  end
end
