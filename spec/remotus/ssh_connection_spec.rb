# frozen_string_literal: true

RSpec.describe Remotus::SshConnection do
  let(:host) { "test.local" }
  let(:cred) { Remotus::Auth::Credential.new("user", "pass") }
  let(:ssh_connection) do
    double(
      Net::SSH::Connection::Session,
      open_channel: double(Net::SSH::Connection::Channel, wait: nil),
      scp: double(Net::SCP, upload!: nil)
    )
  end
  subject { described_class.new(host) }

  before do
    Remotus::Auth.cache[host] = cred
  end

  describe "#initialize" do
    it "creates a new SshConnection" do
      new_connection = described_class.new(host)
      expect(new_connection).to be_a(described_class)
      expect(new_connection.host).to eq(host)
      expect(new_connection.port).to eq(22)
    end
  end

  describe "#type" do
    it "returns :ssh" do
      expect(subject.type).to eq(:ssh)
    end
  end

  describe "#host" do
    it "returns the host" do
      expect(subject.host).to eq(host)
    end
  end

  describe "#port" do
    it "returns the port" do
      expect(subject.port).to eq(22)
    end
  end

  describe "#base_connection" do
    it "creates the connection" do
      expect(Net::SSH).to receive(:start).with(
        host, "user", password: "pass", non_interactive: true, keepalive: true, keepalive_interval: 300
      )
      subject.base_connection
    end
  end

  describe "#connection" do
    it "creates the connection" do
      expect(Net::SSH).to receive(:start).with(
        host, "user", password: "pass", non_interactive: true, keepalive: true, keepalive_interval: 300
      )
      subject.connection
    end
  end

  describe "#port_open?" do
    it "calls Remotus.port_open?" do
      expect(Remotus).to receive(:port_open?).with(host, 22).and_return(true)
      expect(subject.port_open?).to eq(true)
    end
  end

  describe "#run" do
    context "when sudo is true" do
      it "runs the command via sudo over SSH" do
        expect(subject).to receive(:connection).and_return(ssh_connection)
        result = subject.run("ls /root", sudo: true)
        expect(result.command).to eq("ls /root")
      end
    end

    context "when sudo is false" do
      it "runs the command over SSH" do
        expect(subject).to receive(:connection).and_return(ssh_connection)
        result = subject.run("ls /root")
        expect(result.command).to eq("ls /root")
      end
    end
  end

  describe "#run_script" do
    it "uploads the script, marks it executable, and runs it" do
      expect(subject).to receive(:upload).with("local.sh", "/home/user/remote.sh")
      expect(subject).to receive(:run).with("chmod +x /home/user/remote.sh")
      expect(subject).to receive(:run).with("/home/user/remote.sh")
      subject.run_script("local.sh", "/home/user/remote.sh")
    end
  end

  describe "#upload" do
    context "when sudo is true" do
      it "Uploads the file to the user home and moves it to the destination with sudo" do
        expect(ssh_connection.scp).to receive(:upload!).with(
          "local.txt", /\.remote\.txt\w+/, { sudo: true }
        )
        expect(subject).to receive(:connection).and_return(ssh_connection)
        expect(subject).to receive(:run).with(
          %r{/bin/mv -f '\.remote\.txt.*' '/root/remote\.txt'}, sudo: true
        ).and_return(
          Remotus::Result.new("", "", "", "", 0)
        )
        subject.upload("local.txt", "/root/remote.txt", sudo: true)
      end
    end

    context "when sudo is false" do
      it "Uploads the file via SCP" do
        expect(ssh_connection.scp).to receive(:upload!).with("local.txt", "/tmp/remote.txt", {})
        expect(subject).to receive(:connection).and_return(ssh_connection)
        subject.upload("local.txt", "/tmp/remote.txt")
      end
    end
  end

  describe "#download" do
    context "when sudo is true" do
      it "Copies the file to an accessible directory with sudo, downloads it, and remove it" do
        expect(subject).to receive(:run).with(
          %r{/bin/cp -f '/root/remote.txt' '\.remote\.txt.*' && chown user '\.remote\.txt.*'}, sudo: true
        ).and_return(
          Remotus::Result.new("", "", "", "", 0)
        )

        expect(subject).to receive(:run).with(
          %r{/bin/rm -f '\.remote\.txt.*'}, sudo: true
        ).and_return(
          Remotus::Result.new("", "", "", "", 0)
        )

        expect(ssh_connection.scp).to receive(:download!).with(/\.remote\.txt\w+/, "local.txt", { sudo: true })
        expect(subject).to receive(:connection).and_return(ssh_connection)
        subject.download("/root/remote.txt", "local.txt", sudo: true)
      end
    end

    context "when sudo is false" do
      it "Downloads the file via SCP" do
        expect(ssh_connection.scp).to receive(:download!).with("/tmp/remote.txt", "local.txt", {})
        expect(subject).to receive(:connection).and_return(ssh_connection)
        subject.download("/tmp/remote.txt", "local.txt")
      end
    end
  end

  describe "#file_exist?" do
    context "when the file exists" do
      it "returns true" do
        expect(subject).to receive(:run).with(%r{test -f '/tmp/yes.txt' || test -d '/tmp/yes.txt'}).and_return(
          Remotus::Result.new("", "", "", "", 0)
        )
        expect(subject.file_exist?("/tmp/yes.txt")).to eq(true)
      end
    end

    context "when the file does not exist" do
      it "returns false" do
        expect(subject).to receive(:run).with(%r{test -f '/tmp/no.txt' || test -d '/tmp/no.txt'}).and_return(
          Remotus::Result.new("", "", "", "", 1)
        )
        expect(subject.file_exist?("/tmp/no.txt")).to eq(false)
      end
    end
  end
end
