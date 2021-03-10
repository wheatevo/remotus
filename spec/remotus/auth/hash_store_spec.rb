# frozen_string_literal: true

RSpec.describe Remotus::Auth::HashStore do
  subject { described_class.new }
  let(:host) { "test.local" }
  let(:connection) { double(Remotus::SshConnection, host: host) }
  let(:cred) { Remotus::Auth::Credential.new("user", "pass") }

  describe "#credential" do
    it "returns a credential if found or nil" do
      expect(subject.credential(connection)).to eq(nil)
      subject.add(connection, cred)
      expect(subject.credential(connection)).to eq(cred)
    end
  end

  describe "#user" do
    it "returns a user if found or nil" do
      expect(subject.user(connection)).to eq(nil)
      subject.add(connection, cred)
      expect(subject.user(connection)).to eq(cred.user)
    end
  end

  describe "#password" do
    it "returns a password if found or nil" do
      expect(subject.password(connection)).to eq(nil)
      subject.add(connection, cred)
      expect(subject.password(connection)).to eq(cred.password)
    end
  end

  describe "#add" do
    it "adds a credential" do
      expect(subject.credential(connection)).to eq(nil)
      subject.add(connection, cred)
      expect(subject.credential(connection)).to eq(cred)
    end
  end

  describe "#remove" do
    it "removes a credential" do
      expect(subject.credential(connection)).to eq(nil)
      subject.add(connection, cred)
      expect(subject.credential(connection)).to eq(cred)
      subject.remove(connection)
      expect(subject.credential(connection)).to eq(nil)
    end
  end

  describe "#to_s" do
    it "returns HashStore" do
      expect(subject.to_s).to eq("HashStore")
    end
  end
end
