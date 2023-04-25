# frozen_string_literal: true

RSpec.describe Remotus::Logger do
  describe "#new" do
    it "is a ::Logger instance" do
      expect(described_class.new($stdout)).to be_a(Logger)
    end
  end
end
