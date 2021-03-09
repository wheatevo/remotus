# frozen_string_literal: true

RSpec.describe Remotus do
  let(:host) { "testnode.local" }

  before do
    # Remove all host pools between each test
    described_class.clear
  end

  it "has a version number" do
    expect(Remotus::VERSION).not_to be nil
  end

  describe "self#connect" do
    it "returns a cached Remotus::HostPool" do
      expect(described_class).to receive(:host_type).and_return(:ssh)
      pool = described_class.connect(host)
      expect(pool).to be_a(Remotus::HostPool)

      5.times { expect(pool).to be(described_class.connect(host)) }
    end
  end

  describe "self#count" do
    it "returns the number of host pools" do
      expect(described_class).to receive(:host_type).exactly(5).times.and_return(:ssh)
      expect(described_class.count).to eq(0)
      5.times { |i| described_class.connect("a#{i}#{host}") }
      expect(described_class.count).to eq(5)
    end
  end

  describe "self#clear" do
    it "removes all host pools from the pool" do
      expect(described_class).to receive(:host_type).exactly(5).times.and_return(:ssh)
      5.times { |i| described_class.connect("a#{i}#{host}") }
      expect(described_class.count).to eq(5)
      expect(described_class.clear).to eq(5)
      expect(described_class.count).to eq(0)
    end
  end

  describe "self#port_open?" do
    context "when port is open" do
      it "returns true" do
        expect(Socket).to receive(:tcp).with(host, 22, connect_timeout: 1).and_return(true)
        expect(described_class.port_open?(host, 22)).to eq(true)
      end
    end

    context "when port is closed" do
      it "returns false" do
        expect(Socket).to receive(:tcp).with(host, 22, connect_timeout: 1).and_raise("timeout!")
        expect(described_class.port_open?(host, 22)).to eq(false)
      end
    end
  end

  describe "self#host_type" do
    context "when SSH port is available" do
      it "returns :ssh" do
        expect(described_class).to receive(:port_open?).with(
          host, described_class::SshConnection::REMOTE_PORT, timeout: 1
        ).and_return(true)
        expect(described_class.host_type(host)).to eq(:ssh)
      end
    end

    context "When WinRM port is available" do
      it "returns :winrm" do
        expect(described_class).to receive(:port_open?).with(
          host, described_class::SshConnection::REMOTE_PORT, timeout: 1
        ).and_return(false)
        expect(described_class).to receive(:port_open?).with(
          host, described_class::WinrmConnection::REMOTE_PORT, timeout: 1
        ).and_return(true)
        expect(described_class.host_type(host)).to eq(:winrm)
      end
    end

    context "When no port is available" do
      it "returns nil" do
        expect(described_class).to receive(:port_open?).with(
          host, described_class::SshConnection::REMOTE_PORT, timeout: 1
        ).and_return(false)
        expect(described_class).to receive(:port_open?).with(
          host, described_class::WinrmConnection::REMOTE_PORT, timeout: 1
        ).and_return(false)
        expect(described_class.host_type(host)).to eq(nil)
      end
    end
  end

  describe "self#logger" do
    it "returns the cached logger" do
      expect(described_class.logger).to be_a(described_class::Logger)
      expect(described_class.logger).to eq(described_class.logger)
    end
  end

  describe "self#logger=" do
    let(:logger) { ::Logger.new($stdout) }
    it "replaces the current logger" do
      described_class.logger = logger
      expect(described_class.logger).to eq(logger)
    end
  end

  describe "self#log_formatter" do
    it "returns the cached log formatter" do
      expect(described_class.log_formatter).to eq(described_class.logger.formatter)
    end
  end

  describe "self#log_formatter=" do
    let(:formatter) { ::Logger::Formatter.new }

    it "replaces the cached log formatter" do
      original_formatter = described_class.log_formatter
      described_class.log_formatter = formatter
      expect(described_class.log_formatter).to eq(formatter)
      expect(original_formatter).to_not eq(formatter)
    end
  end
end
