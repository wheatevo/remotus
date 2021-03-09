# frozen_string_literal: true

RSpec.describe Remotus::Auth::Credential do
  let(:private_key_data) { "private key data" }
  let(:private_key) { "/home/test/.ssh/id_rsa" }

  subject { described_class.new("user", "pass", private_key: private_key, private_key_data: private_key_data) }

  describe "self#from_hash" do
    it "creates a new credential from a hash" do
      cred = described_class.from_hash(user: "user", password: "password")
      expect(cred).to be_a(described_class)
      expect(cred.user).to eq("user")
      expect(cred.password).to eq("password")
      expect(cred.private_key).to eq(nil)
      expect(cred.private_key_data).to eq(nil)
    end
  end

  describe "#initialize" do
    it "creates a new credential and encrypts sensitive data" do
      cred = described_class.new("user", "password")
      expect(cred).to be_a(described_class)
      expect(cred.user).to eq("user")
      expect(cred.password).to eq("password")
      expect(cred.private_key).to eq(nil)
      expect(cred.private_key_data).to eq(nil)
    end
  end

  describe "#user" do
    it "gets the user" do
      expect(subject.user).to eq("user")
    end
  end

  describe "#user=" do
    it "sets the user" do
      subject.user = "otheruser"
      expect(subject.user).to eq("otheruser")
    end
  end

  describe "#private_key" do
    it "gets the private key path" do
      expect(subject.private_key).to eq(private_key)
    end
  end

  describe "#private_key=" do
    it "sets the private key path" do
      subject.private_key = "/home/user/.ssh/id_rsa2"
      expect(subject.private_key).to eq("/home/user/.ssh/id_rsa2")
    end
  end

  describe "#password" do
    it "gets the password" do
      expect(subject.password).to eq("pass")
    end
  end

  describe "#password=" do
    it "sets the password and encrypts it" do
      subject.password = "mypass"
      expect(subject.password).to eq("mypass")
      expect(subject.instance_variable_get(:@password)).to_not eq("mypass")
    end
  end

  describe "#private_key_data" do
    it "gets the private key data" do
      expect(subject.private_key_data).to eq(private_key_data)
    end
  end

  describe "#private_key_data=" do
    it "sets the private key data and encrypts it" do
      subject.private_key_data = "other data"
      expect(subject.private_key_data).to eq("other data")
      expect(subject.instance_variable_get(:@private_key_data)).to_not eq("other data")
    end
  end

  describe "#to_s" do
    it "does not display sensitive data" do
      expect(subject.to_s).to_not include(subject.password)
    end
  end

  describe "#inspect" do
    it "does not display sensitive data" do
      expect(subject.inspect).to_not include(subject.password)
    end
  end
end
