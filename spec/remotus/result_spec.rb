# frozen_string_literal: true

RSpec.describe Remotus::Result do
  let(:command_result) { described_class.new("command", "stdout", "stderr", "stdoutstderr", 0) }
  let(:failed_command_result) { described_class.new("command", "stdout", "stderr", "stdoutstderr", 1) }

  describe "#initialize" do
    context "when no parameters are provided" do
      it "is initialized with default params" do
        result = described_class.new("", "", "", "")
        expect(result.command).to eq("")
        expect(result.stdout).to eq("")
        expect(result.stderr).to eq("")
        expect(result.output).to eq("")
        expect(result.exit_code).to eq(nil)
      end
    end

    context "when parameters are provided" do
      it "is initialized with provided params" do
        expect(command_result.command).to eq("command")
        expect(command_result.stdout).to eq("stdout")
        expect(command_result.stderr).to eq("stderr")
        expect(command_result.output).to eq("stdoutstderr")
        expect(command_result.exit_code).to eq(0)
      end
    end
  end

  describe "#to_s" do
    it "returns the output as a string" do
      expect(command_result.to_s).to eq("stdoutstderr")
    end
  end

  describe "#error?" do
    context "when the current exit code is an acceptable exit code" do
      it "returns false" do
        expect(command_result.error?).to eq(false)
      end
    end

    context "when the current exit code is not an acceptable exit code" do
      it "returns true" do
        expect(failed_command_result.error?).to eq(true)
        expect(command_result.error?([1, 2, 3])).to eq(true)
      end
    end
  end

  describe "#error!" do
    context "when the current exit code is an acceptable exit code" do
      it "does not raise an exception" do
        expect { command_result.error! }.to_not raise_exception
      end
    end

    context "when the current exit code is not an acceptable exit code" do
      it "raises an exception" do
        expect { failed_command_result.error! }.to raise_exception(/Error encountered executing/)
        expect { command_result.error!([1, 2, 3]) }.to raise_exception(/Error encountered executing/)
      end
    end
  end

  describe "#success?" do
    context "when the current exit code is an acceptable exit code" do
      it "returns true" do
        expect(command_result.success?).to eq(true)
      end
    end

    context "when the current exit code is not an acceptable exit code" do
      it "returns false" do
        expect(failed_command_result.success?).to eq(false)
        expect(command_result.success?([1, 2, 3])).to eq(false)
      end
    end
  end
end
