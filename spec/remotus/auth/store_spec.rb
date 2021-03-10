# frozen_string_literal: true

RSpec.describe Remotus::Auth::Store do
  subject { described_class.new }
  let(:host) { "test.local" }
  let(:connection) { double(Remotus::SshConnection, host: host) }

  describe "#credential" do
    it "raises a Remotus::MissingOverride exception" do
      expect { subject.credential(connection) }.to raise_error(Remotus::MissingOverride)
    end
  end

  describe "#user" do
    it "raises a Remotus::MissingOverride exception" do
      expect { subject.user(connection) }.to raise_error(Remotus::MissingOverride)
    end
  end

  describe "#password" do
    it "raises a Remotus::MissingOverride exception" do
      expect { subject.password(connection) }.to raise_error(Remotus::MissingOverride)
    end
  end
end
