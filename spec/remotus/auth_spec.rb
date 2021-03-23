# frozen_string_literal: true

RSpec.describe Remotus::Auth do
  let(:host) { "testnode.local" }
  let(:connection) { double(Remotus::SshConnection, host: host) }
  let(:cred) { described_class::Credential.new("user", "pass") }
  let(:hash_store) { described_class::HashStore.new }

  before do
    described_class.clear_cache
    described_class.stores = []
  end

  describe "#credential" do
    context "when the cache contains a host credential without a username or password" do
      it "retrieves and caches a new credential" do
        described_class.cache[host] = described_class::Credential.new(nil, nil)
        described_class.stores = [hash_store]
        hash_store.add(connection, cred)
        expect(described_class.credential(connection)).to eq(cred)
      end
    end

    context "when the cache contains a host credential without a username" do
      it "retrieves and caches a new credential" do
        described_class.cache[host] = described_class::Credential.new(nil, "password")
        described_class.stores = [hash_store]
        hash_store.add(connection, cred)
        expect(described_class.credential(connection)).to eq(cred)
      end
    end

    context "when the cache contains a host credential without a password" do
      it "retrieves and caches a new credential" do
        described_class.cache[host] = described_class::Credential.new("diff_user", nil)
        described_class.stores = [hash_store]
        hash_store.add(connection, cred)
        expect(described_class.credential(connection)).to eq(cred)
      end
    end

    context "when the cache contains the host credential" do
      it "returns the credential" do
        described_class.cache[host] = cred
        expect(described_class.credential(connection)).to eq(cred)
      end
    end

    context "when the cache does not contain the host credential" do
      context "when no stores exist" do
        it "raises Remotus::MissingCredential" do
          expect { described_class.credential(connection) }.to raise_error(Remotus::MissingCredential)
        end
      end

      context "when a store without the credential exists" do
        it "raises Remotus::MissingCredential" do
          described_class.stores = [hash_store]
          expect { described_class.credential(connection) }.to raise_error(Remotus::MissingCredential)
        end
      end

      context "when a store with the credential exists" do
        it "caches and returns the credential" do
          described_class.stores = [hash_store]
          hash_store.add(connection, cred)
          expect(described_class.credential(connection)).to eq(cred)
        end
      end
    end
  end

  describe "#cache" do
    it "returns the cache" do
      described_class.cache[host] = cred
      expect(described_class.cache).to eq({ host => cred })
    end
  end

  describe "#clear_cache" do
    it "clears the cache" do
      described_class.cache[host] = cred
      described_class.clear_cache
      expect(described_class.cache).to eq({})
    end
  end

  describe "#stores" do
    it "returns the credential stores" do
      expect(described_class.stores).to eq([])
    end
  end

  describe "#stores=" do
    it "replaces the credential stores with a new value" do
      described_class.stores = [hash_store]
      expect(described_class.stores).to eq([hash_store])
    end
  end
end
