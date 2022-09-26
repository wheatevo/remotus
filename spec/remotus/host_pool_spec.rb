# frozen_string_literal: true

RSpec.describe Remotus::HostPool do
  let(:host) { "testnode.local" }
  let(:cred) { Remotus::Auth::Credential.new("user", "pass") }
  subject { described_class.new(host, port: 22, proto: :ssh) }

  before do
    Remotus::Auth.clear_cache
  end

  describe "#initialize" do
    context "when protocol is unset" do
      context "when host type can be found" do
        it "returns the appropriate connection instance" do
          expect(Remotus).to receive(:host_type).and_return(:ssh)
          host_pool = described_class.new(host)
          expect(host_pool).to be_a(described_class)
          expect(host_pool.with { |c| c }).to be_a(Remotus::SshConnection)

          expect(Remotus).to receive(:host_type).and_return(:winrm)
          host_pool = described_class.new(host)
          expect(host_pool).to be_a(described_class)
          expect(host_pool.with { |c| c }).to be_a(Remotus::WinrmConnection)
        end
      end

      context "when host type cannot be found" do
        it "raises HostTypeDeterminationError" do
          allow(Remotus).to receive(:host_type).and_return(nil)
          expect { described_class.new(host) }.to raise_error(Remotus::HostTypeDeterminationError)
        end
      end
    end

    context "when protocol is set" do
      it "returns the appropriate connection instance" do
        host_pool = described_class.new(host, proto: :ssh)
        expect(host_pool).to be_a(described_class)
        expect(host_pool.with { |c| c }).to be_a(Remotus::SshConnection)

        host_pool = described_class.new(host, proto: :winrm)
        expect(host_pool).to be_a(described_class)
        expect(host_pool.with { |c| c }).to be_a(Remotus::WinrmConnection)
      end
    end

    context "when port is set" do
      it "uses the provided port" do
        host_pool = described_class.new(host, proto: :ssh, port: 2222)
        expect(host_pool).to be_a(described_class)
        expect(host_pool.with { |c| c }).to be_a(Remotus::SshConnection)
        expect(host_pool.port).to eq(2222)

        host_pool = described_class.new(host, proto: :winrm, port: 54_321)
        expect(host_pool).to be_a(described_class)
        expect(host_pool.with { |c| c }).to be_a(Remotus::WinrmConnection)
        expect(host_pool.port).to eq(54_321)
      end
    end

    context "when timeout is set" do
      it "uses the provided timeout" do
        host_pool = described_class.new(host, proto: :ssh, timeout: 300)
        expect(host_pool.timeout).to eq(300)
      end
    end

    context "when size is set" do
      it "uses the provided size" do
        host_pool = described_class.new(host, proto: :ssh, size: 5)
        expect(host_pool.size).to eq(5)
      end
    end

    context "when metadata are set" do
      let(:meta) do
        {
          data1: 123,
          "Very odd string key" => 555,
          "%&*(&!%another_inValid key    with strange things" => "test",
          { k: :v } => "oof"
        }
      end

      it "generates dynamic methods for each metadata entry" do
        host_pool = described_class.new(host, proto: :ssh, **meta)
        meta.each do |k, v|
          expect(host_pool.send(k.to_s.to_method_name)).to eq(v)
          expect { host_pool.send("#{k.to_s.to_method_name}=", "new_value") }.to_not raise_error
          expect(host_pool.data1).to eq("new_value")
        end
      end
    end

    context "when metadata are set to a conflicting key" do
      it "raises an exception" do
        described_class.instance_methods.each do |k|
          # Skip instance methods that will not conflict or input that will be interpreted as a keyword arg
          next if k != k.to_s.to_method_name || %i[size timeout port proto].include?(k)

          bad_meta = { k => "value" }
          expect { described_class.new(host, port: 22, proto: :ssh, **bad_meta) }.to raise_error(Remotus::InvalidMetadataKey)
        end
      end
    end
  end

  describe "#close" do
    it "closes the connection on each open connection" do
      expect(subject.instance_variable_get(:@pool)).to receive(:reload)

      expect { subject.close }.to_not raise_error
    end
  end

  describe "#expiration_time" do
    it "returns the expiration time" do
      expect(subject.expiration_time).to be_a(Time)
    end
  end

  describe "#size" do
    it "returns the size" do
      expect(subject.size).to eq(2)
    end
  end

  describe "#timeout" do
    it "returns the timeout" do
      expect(subject.timeout).to eq(600)
    end
  end

  describe "#proto" do
    it "returns the proto" do
      expect(subject.proto).to eq(:ssh)
    end
  end

  describe "#host" do
    it "returns the host" do
      expect(subject.host).to eq(host)
    end
  end

  describe "#expired?" do
    context "when expiration time is after the current time" do
      it "returns false" do
        expect(subject.expired?).to eq(false)
      end
    end

    context "when expiration time is before the current time" do
      it "returns true" do
        subject.expire
        expect(subject.expired?).to eq(true)
      end
    end
  end

  describe "#expire" do
    it "expires the pool" do
      expect(subject.expired?).to eq(false)
      subject.expire
      expect(subject.expired?).to eq(true)
    end
  end

  describe "#with" do
    it "passes the associated connection to a block" do
      expect(subject.with { |c| c }).to be_a(Remotus::SshConnection)
    end
  end

  describe "#port" do
    it "returns the port" do
      expect(subject.port).to eq(22)
    end
  end

  describe "#port_open?" do
    it "calls port_open? on the connection" do
      expect(subject.with { |c| c }).to receive(:port_open?)
      subject.port_open?
    end
  end

  describe "#run" do
    it "calls run on the connection" do
      expect(subject.with { |c| c }).to receive(:run)
      subject.run("ls")
    end
  end

  describe "#run_script" do
    it "calls run_script on the connection" do
      expect(subject.with { |c| c }).to receive(:run_script)
      subject.run_script("local.sh", "remote.sh")
    end
  end

  describe "#upload" do
    it "calls upload on the connection" do
      expect(subject.with { |c| c }).to receive(:upload)
      subject.upload("local", "remote")
    end
  end

  describe "#download" do
    it "calls download on the connection" do
      expect(subject.with { |c| c }).to receive(:download)
      subject.download("remote", "local")
    end
  end

  describe "#file_exist?" do
    it "calls run on the connection" do
      expect(subject.with { |c| c }).to receive(:file_exist?)
      subject.file_exist?("remote")
    end
  end

  describe "#credential" do
    it "Attempts to gather the credential from the credential store" do
      Remotus::Auth.cache[host] = cred
      subject.credential
    end
  end

  describe "#credential=" do
    it "Sets the host credential in the auth cache" do
      subject.credential = cred
      expect(subject.credential).to eq(cred)
    end
  end

  describe "#[]" do
    it "returns metadata by key" do
      expect(subject["not a key"]).to eq(nil)

      subject["valid key"] = 123
      expect(subject["valid key"]).to eq(123)
      expect(subject.valid_key).to eq(123)
    end
  end

  describe "#[]=" do
    it "sets metadata by key" do
      subject["new key"] = 123
      expect(subject["new key"]).to eq(123)
      expect(subject.new_key).to eq(123)
    end
  end
end
