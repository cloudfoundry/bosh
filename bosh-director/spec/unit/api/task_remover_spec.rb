require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/director/api/task_remover'

module Bosh::Director::Api
  describe TaskRemover do
    describe '#remove' do
      include FakeFS::SpecHelpers

      subject(:remover) { described_class.new(3, double('logger')) }

      context 'when there are fewer than max_tasks in the database' do
        before do
          2.times do |i|
            task = Bosh::Director::Models::Task.make(output: "/director/tasks/#{i}")
            FileUtils.mkpath(task.output)
          end
        end

        it 'keeps all tasks files' do
          expect {
            remover.remove
          }.not_to change {
            Dir['/director/tasks/**/*']
          }
        end

        it 'keeps all tasks in the database' do
          expect {
            remover.remove
          }.not_to change {
            Bosh::Director::Models::Task.count
          }
        end
      end

      context 'when there are exactly max_tasks in the database' do
        before do
          3.times do |i|
            task = Bosh::Director::Models::Task.make(output: "/director/tasks/#{i}")
            FileUtils.mkpath(task.output)
          end
        end

        it 'keeps all tasks files' do
          expect {
            remover.remove
          }.not_to change {
            Dir['/director/tasks/**/*']
          }
        end

        it 'keeps all tasks in the database' do
          expect {
            remover.remove
          }.not_to change {
            Bosh::Director::Models::Task.count
          }
        end
      end

      context 'when there is one more than max_tasks in the database' do
        before do
          4.times do |i|
            task = Bosh::Director::Models::Task.make(output: "/director/tasks/#{i}")
            FileUtils.mkpath(task.output)
          end
        end

        it 'keeps the latest `max_tasks` tasks files' do
          expect {
            remover.remove
          }.to change {
            Dir['/director/tasks/*']
          }.from(
            (0...4).map {|i| "/director/tasks/#{i}"}
          ).to(
            (1...4).map { |i| "/director/tasks/#{i}" }
          )
        end

        it 'keeps the latest `max_tasks` tasks in the database' do
          expect {
            remover.remove
          }.to change {
            Bosh::Director::Models::Task.count
          }.from(4).to(3)
        end
      end

      context 'when there are 2 more than max_tasks in the database' do
        before do
          5.times do |i|
            task = Bosh::Director::Models::Task.make(output: "/director/tasks/#{i}")
            FileUtils.mkpath(task.output)
          end
        end

        it 'removes the oldest 2 tasks files because it eventually converges to `max_tasks`' do
          expect {
            remover.remove
          }.to change {
            Dir['/director/tasks/*']
          }.from(
                 (0...5).map {|i| "/director/tasks/#{i}"}
               ).to(
                 (2...5).map { |i| "/director/tasks/#{i}" }
               )
        end

        it 'removes the oldest 2 database entries because it eventually converges to `max_tasks`' do
          expect {
            remover.remove
          }.to change {
            Bosh::Director::Models::Task.count
          }.from(5).to(3)
        end
      end

      context 'when there are 10 more than max_tasks in the database' do
        before do
          13.times do |i|
            task = Bosh::Director::Models::Task.make(output: "/director/tasks/#{i}")
            FileUtils.mkpath(task.output)
          end
        end

        it 'removes 2 files older than the latest `max_tasks` because it eventually converges to `max_tasks`' do
          expect {
            remover.remove
          }.to change {
            Dir['/director/tasks/*'].sort
          }.from(
            (0...13).map { |i| "/director/tasks/#{i}" }.sort
          ).to(
            ((0...8).to_a + (10...13).to_a).map { |i| "/director/tasks/#{i}" }.sort
          )
        end

        it 'removes the 2 database entries older than the latest `max_tasks` because it eventually converges to `max_tasks`' do
          expect {
            remover.remove
          }.to change {
            Bosh::Director::Models::Task.map(:id)
          }.from((1..13).to_a).to((1..13).to_a - [9,10])
        end
      end
    end
  end
end
