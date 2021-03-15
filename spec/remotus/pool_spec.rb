# frozen_string_literal: true

RSpec.describe Remotus::Pool do
  let(:host) { "testhost.local" }

  before do
    # Remove all host pools before each test
    described_class.clear
  end

  describe "#connect" do
    it "gets the SSH host pool for the provided host and caches it" do
      host_pool = described_class.connect(host, proto: :ssh)
      expect(host_pool).to be_a(Remotus::HostPool)
      expect(host_pool).to be(described_class.connect(host, proto: :ssh))
    end

    context "when provided different parameters" do
      it "creates a new host pool" do
        host_pool = described_class.connect(host, proto: :ssh)
        expect(host_pool).to be_a(Remotus::HostPool)
        expect(host_pool).to_not be(described_class.connect(host, proto: :winrm))
        host_pool = described_class.connect(host, proto: :winrm)
        expect(host_pool).to be(described_class.connect(host, proto: :winrm))

        expect(host_pool).to_not be(described_class.connect(host, proto: :winrm, location: "Madrid", company: "Test Co"))
        host_pool = described_class.connect(host)
        expect(host_pool).to be(described_class.connect(host, proto: :winrm, location: "Madrid", company: "Test Co"))
        expect(host_pool).to_not be(described_class.connect(host, proto: :winrm, location: "Madrid", company: "Test Comp"))
      end
    end
  end

  describe "#count" do
    it "gets the number of host pools" do
      expect(described_class.count).to eq(0)
      described_class.connect(host, proto: :ssh)
      expect(described_class.count).to eq(1)
    end
  end

  describe "#reap" do
    context "when the pool is empty" do
      it "does not remove host pools" do
        expect(described_class.reap).to eq(0)
      end
    end

    context "when the pool has no expired host pools" do
      it "does not remove host pools" do
        described_class.connect(host, proto: :ssh)
        expect(described_class.reap).to eq(0)
        expect(described_class.count).to eq(1)
      end
    end

    context "when the pool has expired host pools" do
      it "removes expired host pools" do
        described_class.connect(host, proto: :ssh).expire
        expect(described_class.count).to eq(1)
        expect(described_class.reap).to eq(1)
        expect(described_class.count).to eq(0)
      end
    end
  end

  describe "#clear" do
    context "when the pool is empty" do
      it "does not remove host pools" do
        expect(described_class.clear).to eq(0)
        expect(described_class.count).to eq(0)
      end
    end

    context "when the pool contains host pools" do
      it "removes all host pools" do
        described_class.connect(host, proto: :ssh)
        expect(described_class.count).to eq(1)
        expect(described_class.clear).to eq(1)
        expect(described_class.count).to eq(0)
      end
    end
  end
end
