require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::IndexAssigner do
    subject(:assigner) { PlacementPlanner::IndexAssigner.new }

    describe '#assign_indexes' do
      context 'only new' do
        it 'assigns instances properly' do
          zoned_instances = {
            :desired_new => [DesiredInstance.new, DesiredInstance.new],
            :desired_existing => [],
            :obsolete => [],
          }

          assigner.assign_indexes(zoned_instances)

          expect(zoned_instances[:desired_existing]).to eq([])
          indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
          expect(indexes).to match_array([0, 1])
          expect(zoned_instances[:obsolete]).to eq([])
        end
      end

      context 'only existing' do
        context 'when existing instances have unique indexes' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [],
              :desired_existing => build_existing([0, 1]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            expect(zoned_instances[:desired_new]).to eq([])
            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([0, 1])
            expect(zoned_instances[:obsolete]).to eq([])
          end
        end

        context 'when existing instances have non-unique indexes' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [],
              :desired_existing => build_existing([1, 1]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            expect(zoned_instances[:desired_new]).to eq([])
            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([0, 1])
            expect(zoned_instances[:obsolete]).to eq([])
          end
        end
      end

      context 'existing and obsolete' do
        context 'when there are no conflicting indexes' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [],
              :desired_existing => build_existing([0, 1]),
              :obsolete => build_obsolete([2, 3]),
            }

            assigner.assign_indexes(zoned_instances)
            expect(zoned_instances[:desired_new]).to eq([])
            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([0, 1])
            expect(zoned_instances[:obsolete].map(&:index)).to eq([2,3])
          end
        end

        context 'when existing instances have conflicting indexes' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [],
              :desired_existing => build_existing([1, 1]),
              :obsolete => build_obsolete([0, 3]),
            }

            assigner.assign_indexes(zoned_instances)
            expect(zoned_instances[:desired_new]).to eq([])
            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([1, 2])
            expect(zoned_instances[:obsolete].map(&:index)).to eq([0,3])
          end
        end
      end

      context 'new & existing' do

        context 'when existing instances do not have indexes conflicting with each other' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new, DesiredInstance.new],
              :desired_existing => build_existing([1, 2]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([0, 3])

            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([1, 2])

            expect(zoned_instances[:obsolete]).to eq([])
          end
        end

        context 'when existing instances have indexes conflicting with each other' do
          it 'prefers indexes to keep on instances with the same job name' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new, DesiredInstance.new],
              :desired_existing => build_existing([1, 1, 1, 2]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([0, 1, 2, 3])

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([4, 5])

            expect(zoned_instances[:obsolete]).to eq([])
          end

          it 'prefers to keep indexes for instance that match desired job name' do
            # when migrating db_z1 to db, if db has instance with index 0
            # and db_z1 has an index 0, we want to preserve index 0 only on db
            # and db_z1 should get next available

            desired_existing_with_matching_job_name = {
              :desired_instance => DesiredInstance.new(double(:job, name: 'db')),
              :existing_instance_model => Bosh::Director::Models::Instance.make(index: 0, job: 'db')
            }

            desired_existing_with_non_matching_job_name = {
              :desired_instance => DesiredInstance.new(double(:job, name: 'db')),
              :existing_instance_model => Bosh::Director::Models::Instance.make(index: 0, job: 'db_z1')
            }

            zoned_instances = {
              :desired_new => [],
              :desired_existing => [
                desired_existing_with_non_matching_job_name,
                desired_existing_with_matching_job_name
              ],
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            expect(desired_existing_with_non_matching_job_name[:desired_instance].index).to eq(1)
            expect(desired_existing_with_matching_job_name[:desired_instance].index).to eq(0)
          end
        end

        context 'when an existing instance index is 0' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new, DesiredInstance.new],
              :desired_existing => build_existing([0]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([1, 2])

            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([0])

            expect(zoned_instances[:obsolete]).to eq([])
          end
        end

        context 'when an existing instance index is 1' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new, DesiredInstance.new],
              :desired_existing => build_existing([1]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([0, 2])

            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([1])

            expect(zoned_instances[:obsolete]).to eq([])
          end
        end


        context 'when an existing instance index is out of the expected range of indexes' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new, DesiredInstance.new],
              :desired_existing => build_existing([9]),
              :obsolete => [],
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([0, 1])

            indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
            expect(indexes).to match_array([9])

            expect(zoned_instances[:obsolete]).to eq([])
          end
        end
      end

      context 'new & obsolete' do
        context 'when obsolete instances have indexes that would otherwise be used' do
          context 'and there are the same number of desired instances and obsolete instances' do
            it 'assigns indexes properly' do
              zoned_instances = {
                :desired_new => [DesiredInstance.new, DesiredInstance.new],
                :desired_existing => [],
                :obsolete => build_obsolete([0, 1]),
              }

              assigner.assign_indexes(zoned_instances)

              indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
              expect(indexes).to match_array([2, 3])

              expect(zoned_instances[:desired_existing]).to eq([])

              indexes = zoned_instances[:obsolete].map {|instance| instance.index}
              expect(indexes).to eq([0, 1])
            end
          end

          context 'and there are fewer desired instances than obsolete instances' do
            it 'assigns indexes properly' do
              zoned_instances = {
                :desired_new => [DesiredInstance.new],
                :desired_existing => [],
                :obsolete => build_obsolete([0, 1]),
              }

              assigner.assign_indexes(zoned_instances)

              indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
              expect(indexes).to match_array([2])

              expect(zoned_instances[:desired_existing]).to eq([])

              indexes = zoned_instances[:obsolete].map {|instance| instance.index}
              expect(indexes).to eq([0, 1])
            end
          end

          context 'and there are more desired instances that obsolete instances' do
            it 'assigns indexes properly' do
              zoned_instances = {
                :desired_new => [DesiredInstance.new, DesiredInstance.new, DesiredInstance.new],
                :desired_existing => [],
                :obsolete => build_obsolete([1, 3]),
              }

              assigner.assign_indexes(zoned_instances)

              indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
              expect(indexes).to match_array([0, 2, 4])

              expect(zoned_instances[:desired_existing]).to eq([])

              indexes = zoned_instances[:obsolete].map {|instance| instance.index}
              expect(indexes).to eq([1, 3])
            end
          end
        end

        context 'when obsolete instances have non-unique indexes that would otherwise be used' do
          it 'assigns indexes properly' do
            zoned_instances = {
              :desired_new => [DesiredInstance.new],
              :desired_existing => [],
              :obsolete => build_obsolete([0, 0]),
            }

            assigner.assign_indexes(zoned_instances)

            indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
            expect(indexes).to match_array([1])

            expect(zoned_instances[:desired_existing]).to eq([])

            indexes = zoned_instances[:obsolete].map {|instance| instance.index}
            expect(indexes).to eq([0, 0])
          end
        end
      end

      context 'new, existing and obsolete' do
        it 'assigns indexes properly' do
          zoned_instances = {
            :desired_new => [DesiredInstance.new, DesiredInstance.new, DesiredInstance.new],
            :desired_existing => build_existing([2, 2]),
            :obsolete => build_obsolete([0, 4]),
          }

          assigner.assign_indexes(zoned_instances)

          indexes = zoned_instances[:desired_new].map { |desired_instance| desired_instance.index }
          expect(indexes).to match_array([3, 5, 6])

          indexes = zoned_instances[:desired_existing].map { |result| result[:desired_instance].index }
          expect(indexes).to match_array([1, 2])

          indexes = zoned_instances[:obsolete].map {|instance| instance.index}
          expect(indexes).to eq([0, 4])
        end
      end
    end

    def build_existing(indexes)
      indexes.map do |index|
        desired_existing_instance(index: index)
      end
    end

    def desired_existing_instance(options)
      {
        :desired_instance => DesiredInstance.new(double(:job, name: 'db')),
        :existing_instance_model => Bosh::Director::Models::Instance.make({:index => options[:index]})
      }
    end

    def build_obsolete(indexes)
      indexes.map do |index|
        Bosh::Director::Models::Instance.make({:index => index})
      end
    end
  end
end
