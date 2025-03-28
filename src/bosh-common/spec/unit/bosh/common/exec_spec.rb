require 'spec_helper'

module Bosh::Common
  describe Exec do
    let(:opts) do
      {}
    end

    context "existing command" do

      context "executes successfully" do
        it "should not fail" do
          expect(Exec.sh("ls /", opts)).to be_success
        end

        it "should execute block" do
          block = false
          Exec.sh("ls /", opts) do
            block = true
          end
          expect(block).to be(true)
        end
      end

      context "fails to execute" do
        it "should raise error by default" do
          expect {
            Exec.sh("ls /asdasd 2>&1", opts)
          }.to raise_error { |error|
            expect(error).to be_a Exec::Error
            expect(error.output).to match(/No such file or directory/)
          }
        end

        it "should yield block on false" do
          opts[:yield] = :on_false
          block = false
          Exec.sh("ls /asdasd 2>&1", opts) do
            block = true
          end
          expect(block).to be(true)
        end

        it "should return result" do
          opts[:on_error] = :return
          expect(Exec.sh("ls /asdasd 2>&1", opts)).to be_failed
        end
      end
    end

    context "missing command" do
      it "should raise error by default" do
        expect {
          Exec.sh("/asdasd 2>&1", opts)
        }.to raise_error(Exec::Error)
      end

      it "should not raise error when requested" do
        opts[:on_error] = :return
        expect { Exec.sh("/asdasd 2>&1", opts) }.to_not raise_error
      end

      it "should execute block when requested" do
        opts[:yield] = :on_false
        expect {
          Exec.sh("/asdasd 2>&1", opts) { raise "foo" }
        }.to raise_error("foo")
      end

    end

    context "mock" do
      it "should be possible fake result" do
        cmd = "ls /"
        result = Exec::Result.new(cmd, "output", 0)
        expect(Exec).to receive(:sh).with(cmd).and_return(result)
        result = Exec.sh(cmd)
        expect(result).to be_success
      end
    end

    context "module" do
      it "should be possible to invoke as a module" do
        expect(Exec.sh("ls /")).to be_success
      end
    end

    context "include" do
      class IncludeTest
        include Exec

        def run
          sh("ls /")
        end

        def self.run
          sh("ls /")
        end
      end

      it "should add instance method" do
        inc = IncludeTest.new
        expect(inc.run).to be_success
      end

      it "should add class method" do
        expect(IncludeTest.run).to be_success
      end
    end
  end
end
