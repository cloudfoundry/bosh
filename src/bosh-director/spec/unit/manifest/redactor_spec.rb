require 'spec_helper'

module Bosh::Director
  describe Redactor do
    subject(:redactor) do
      described_class.new
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

        expect(redactor.redact_properties!(manifest_obj)).to eq({
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

          expect(redactor.redact_properties!(manifest_obj)).to eq({
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

        expect(redactor.redact_properties!(manifest_obj)).to eq(manifest_obj)
      end
    end
  end
end
