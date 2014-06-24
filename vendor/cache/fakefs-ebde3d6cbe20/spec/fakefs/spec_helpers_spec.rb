require 'spec_helper'

module FakeFS
  describe SpecHelpers do
    before do
      @rspec_example_group = Class.new do
        def self.before(sym = :each)
          yield if block_given?
        end

        def self.after(sym = :each)
          yield if block_given?
        end
      end
    end

    describe "when extending" do
      context "before each" do
        it "should call it" do
          @rspec_example_group.should_receive(:before).with(:each)
          @rspec_example_group.extend FakeFS::SpecHelpers
        end

        it "should call FakeFS.activate!" do
          FakeFS.should_receive(:activate!)
          @rspec_example_group.extend FakeFS::SpecHelpers
        end
      end

      context "after each" do
        it "should call it" do
          @rspec_example_group.should_receive(:after).with(:each)
          @rspec_example_group.extend FakeFS::SpecHelpers
        end

        it "should deactivate fakefs" do
          FakeFS.should_receive(:deactivate!)
          @rspec_example_group.extend FakeFS::SpecHelpers
        end

        it "should clear the fakefs filesystem for the next run" do
          FakeFS::FileSystem.should_receive(:clear)
          @rspec_example_group.extend FakeFS::SpecHelpers
        end
      end
    end

    describe "when including" do
      it "should call before :each" do
        @rspec_example_group.should_receive(:before)
        @rspec_example_group.class_eval do
          include FakeFS::SpecHelpers
        end
      end
    end

    describe SpecHelpers::All do
      describe "when extending" do
        context "before :all" do
          it "should call it" do
            @rspec_example_group.should_receive(:before).with(:all)
            @rspec_example_group.extend FakeFS::SpecHelpers::All
          end

          it "should call FakeFS.activate!" do
            FakeFS.should_receive(:activate!)
            @rspec_example_group.extend FakeFS::SpecHelpers::All
          end
        end

        context "after :all" do
          it "should call it" do
            @rspec_example_group.should_receive(:after).with(:all)
            @rspec_example_group.extend FakeFS::SpecHelpers::All
          end

          it "should call FakeFS.deactivate!" do
            FakeFS.should_receive(:deactivate!)
            @rspec_example_group.extend FakeFS::SpecHelpers::All
          end

          it "should not call FakeFS::FileSystem.clear" do
            FakeFS::FileSystem.should_not_receive(:clear)
            @rspec_example_group.extend FakeFS::SpecHelpers::All
          end
        end
      end

      describe "when including" do
        context "before :all" do
          it "should call it" do
            @rspec_example_group.should_receive(:before)
            @rspec_example_group.class_eval do
              include FakeFS::SpecHelpers::All
            end
          end
        end
      end
    end
  end
end
