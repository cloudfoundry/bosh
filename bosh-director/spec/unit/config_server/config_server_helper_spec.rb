require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigServerHelper do
    before do
      @helper = Object.new
      @helper.extend(ConfigServerHelper)
    end

    describe '#is_placeholder?' do
      it 'should return true if value is placeholder' do
        placeholders = [
          '((smurf))', '((((smurf))))', '((!smurf))', '(())', '(( ))',
          '((  ))', '(( smurf))', '((/smurf))', '((/smurf))', '((/smurf))',
          '((/))', '((vroom vroo/m))'
        ]

        placeholders.each do |placeholder|
          expect(@helper.is_placeholder?(placeholder)).to be_truthy
        end
      end

      it 'should return false if value is not a placeholder' do
        not_placeholders = [
          '((smurf', '(!smurf))', 'smurf))', '((smurf', '(( smurf)',
          '(()', '((', '()'
        ]

        not_placeholders.each do |not_placeholder|
          expect(@helper.is_placeholder?(not_placeholder)).to be_falsey
        end
      end
    end

    describe '#extract_placeholder_key' do
      context 'when key meets specs' do
        it 'should return the value passed in without brackets' do
          keys = {
            '((smurf))' => 'smurf',
            '((smurf_))' => 'smurf_',
            '((1smurf))' => '1smurf',
            '((1smurf-))' => '1smurf-',
            '((1sm_urf-))' => '1sm_urf-',
            '((123_-))' => '123_-',
            '((123))' => '123',
            '((_))' => '_',
            '((/smurf))' => '/smurf',
            '((/smurf/gargamel))' => '/smurf/gargamel',
            '((/smurf/gargamel/cat))' => '/smurf/gargamel/cat',
            '((/smurf/gar_gamel))' => '/smurf/gar_gamel'
          }

          keys.each do |k, v|
            expect(@helper.extract_placeholder_key(k)).to eq(v)
          end
        end

        it 'should handle keys starting with bang' do
          keys = {
            '((!/smurf/gar_gamel))' => '/smurf/gar_gamel',
            '((!smurf))' => 'smurf',
            '((!smurf/cat))' => 'smurf/cat',
          }

          keys.each do |k, v|
            expect(@helper.extract_placeholder_key(k)).to eq(v)
          end
        end
      end

      context 'when key does NOT meet specs' do
        context 'when key has invalid characters' do
          it 'should raise a ConfigServerIncorrectKeySyntax error' do
            invalid_placeholders_keys = [
              '(())', '(( ))', '((%))', '((  ))', '((123 345))', '((@bosh))',
              '((hello_)))', '((t*))', '(()))', '((())))', '((smurf cat))'
            ]

            invalid_placeholders_keys.each do |invalid_entity|
              expect {
                @helper.extract_placeholder_key(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectKeySyntax,
                     "Placeholder key '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must only contain alphanumeric, underscores, dashes, or forward slash characters"
                   )
            end
          end
        end

        context 'when key ends with a forward slash' do
          it 'should raise a ConfigServerIncorrectKeySyntax error' do
            invalid_placeholders_keys = [
              '((/))', '((hello/))', '((//))', '((/test/))', '((test//))', '((test///))'
            ]

            invalid_placeholders_keys.each do |invalid_entity|
              expect {
                @helper.extract_placeholder_key(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectKeySyntax,
                     "Placeholder key '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not end with a forward slash"
                   )
            end
          end
        end

        context 'when key has two consecutive forward slashes' do
          it 'should raise a ConfigServerIncorrectKeySyntax error' do
            invalid_placeholders_keys = [
              '((//test))', '((test//test))', '((//test//test))'
            ]

            invalid_placeholders_keys.each do |invalid_entity|
              expect {
                @helper.extract_placeholder_key(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectKeySyntax,
                     "Placeholder key '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not contain two consecutive forward slashes"
                   )
            end
          end
        end

        context 'when key has an exclamation mark other than at the start of the key (for spiff)' do
          it 'should raise a ConfigServerIncorrectKeySyntax error' do
            invalid_placeholders_keys = [
              '((!!/test))', '((!test/test!))', '((/!/test/!/test))', '((!!/test))', '((!))', '((/!))', '((!_!))'
            ]

            invalid_placeholders_keys.each do |invalid_entity|
              expect {
                @helper.extract_placeholder_key(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectKeySyntax,
                     "Placeholder key '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' contains invalid character '!'. If it is included for spiff, " +
                       'it should only be at the beginning of the key. Note: it will not be considered a part of the key'
                   )
            end
          end
        end
      end
    end

    describe '#add_prefix_if_not_absolute' do
      context 'when key is absolute' do
        it 'should return key as is' do
          input_key = '/dir/dep/key'
          expected_key = '/dir/dep/key'
          expect(@helper.add_prefix_if_not_absolute(input_key, 'dir2', 'dep2')).to eq(expected_key)
        end
      end

      context 'when key is not absolute' do
        context 'and both director and deployment is specified' do
          it 'should return key with director and deployment prefix' do
            input_key = 'key'
            director = 'dir'
            deployment = 'dep'

            expected_key = '/dir/dep/key'
            expect(@helper.add_prefix_if_not_absolute(input_key, director, deployment)).to eq(expected_key)
          end
        end
      end
    end
  end
end
