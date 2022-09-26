# frozen_string_literal: true

RSpec.describe Remotus::WinrmConnection do
  let(:host) { "test.local" }
  let(:cred) { Remotus::Auth::Credential.new("domain\\user", "pass") }
  let(:winrm_connection) do
    double(WinRM::Connection, shell: double(WinRM::Shells::Powershell))
  end

  let(:winrm_elevated_connection) do
    double(WinRM::Connection, shell: double(WinRM::Shells::Elevated))
  end

  let(:winrm_file_manager) do
    double(WinRM::FS::FileManager)
  end

  let(:winrm_result) do
    double(WinRM::Output, stdout: "", stderr: "", output: "", exitcode: 0)
  end

  subject { described_class.new(host) }

  before do
    Remotus::Auth.cache[host] = cred
  end

  describe "#initialize" do
    it "creates a new WinrmConnection" do
      new_connection = described_class.new(host)
      expect(new_connection).to be_a(described_class)
      expect(new_connection.host).to eq(host)
      expect(new_connection.port).to eq(5985)
    end
  end

  describe "#type" do
    it "returns :winrm" do
      expect(subject.type).to eq(:winrm)
    end
  end

  describe "#host" do
    it "returns the host" do
      expect(subject.host).to eq(host)
    end
  end

  describe "#port" do
    it "returns the port" do
      expect(subject.port).to eq(5985)
    end
  end

  describe "#base_connection" do
    it "creates the base connection with powershell privilege" do
      expect(WinRM::Connection).to receive(:new).with(
        endpoint: "http://#{host}:5985/wsman",
        transport: :negotiate,
        user: cred.user,
        password: cred.password
      ).and_return(winrm_connection)
      subject.base_connection
    end

    it "creates the base connection with elevated privilege" do
      expect(WinRM::Connection).to receive(:new).with(
        endpoint: "http://#{host}:5985/wsman",
        transport: :negotiate,
        user: cred.user,
        password: cred.password
      ).and_return(winrm_elevated_connection)
      subject.base_connection
    end
  end

  describe "#connection" do
    it "creates the connection shell with powershell privilege" do
      expect(WinRM::Connection).to receive(:new).with(
        endpoint: "http://#{host}:5985/wsman",
        transport: :negotiate,
        user: cred.user,
        password: cred.password
      ).and_return(winrm_connection)
      subject.connection
    end

    it "creates the connection shell with elevated privilege" do
      expect(WinRM::Connection).to receive(:new).with(
        endpoint: "http://#{host}:5985/wsman",
        transport: :negotiate,
        user: cred.user,
        password: cred.password
      ).and_return(winrm_elevated_connection)
      subject.connection
    end
  end

  describe "#close" do
    it "closes the associated connection" do
      subject.connection
      expect(subject.instance_variable_get(:@connection)).to receive(:close)
      subject.close

      expect(subject.instance_variable_get(:@connection)).to eq(nil)
      expect(subject.instance_variable_get(:@base_connection)).to eq(nil)
    end
  end

  describe "#port_open?" do
    it "calls Remotus.port_open?" do
      expect(Remotus).to receive(:port_open?).with(host, 5985).and_return(true)
      expect(subject.port_open?).to eq(true)
    end
  end

  describe "#run" do
    it "runs the command over WinRM with powershell" do
      expect(subject).to receive(:base_connection).and_return(winrm_connection)
      expect(winrm_connection.shell).to receive(:run).with("dir").and_return(winrm_result)
      result = subject.run("dir")
      expect(result.command).to eq("dir")
    end

    it "runs the command over WinRM with elevated" do
      expect(subject).to receive(:base_connection).and_return(winrm_elevated_connection)
      expect(winrm_elevated_connection.shell).to receive(:run).with("dir").and_return(winrm_result)
      result = subject.run("dir")
      expect(result.command).to eq("dir")
    end
  end

  describe "#run_script" do
    it "uploads the script and runs it" do
      expect(subject).to receive(:upload).with("local.ps1", "remote.ps1")
      expect(subject).to receive(:run).with("remote.ps1")
      subject.run_script("local.ps1", "remote.ps1")
    end
  end

  describe "#upload" do
    it "Uploads the file" do
      expect(subject).to receive(:base_connection).and_return(winrm_connection)
      expect(WinRM::FS::FileManager).to receive(:new).with(winrm_connection).and_return(winrm_file_manager)
      expect(winrm_file_manager).to receive(:upload).with("local.txt", "remote.txt")
      subject.upload("local.txt", "remote.txt")
    end
  end

  describe "#download" do
    it "Downloads the file" do
      expect(subject).to receive(:base_connection).and_return(winrm_connection)
      expect(WinRM::FS::FileManager).to receive(:new).with(winrm_connection).and_return(winrm_file_manager)
      expect(winrm_file_manager).to receive(:download).with("remote.txt", "local.txt")
      subject.download("remote.txt", "local.txt")
    end
  end

  describe "#file_exist?" do
    context "when the file exists" do
      it "returns true" do
        expect(subject).to receive(:base_connection).and_return(winrm_connection)
        expect(WinRM::FS::FileManager).to receive(:new).with(winrm_connection).and_return(winrm_file_manager)
        expect(winrm_file_manager).to receive(:exists?).with("C:\\remote.txt").and_return(true)
        expect(subject.file_exist?("C:\\remote.txt")).to eq(true)
      end
    end

    context "when the file does not exist" do
      it "returns false" do
        expect(subject).to receive(:base_connection).and_return(winrm_connection)
        expect(WinRM::FS::FileManager).to receive(:new).with(winrm_connection).and_return(winrm_file_manager)
        expect(winrm_file_manager).to receive(:exists?).with("C:\\remote.txt").and_return(false)
        expect(subject.file_exist?("C:\\remote.txt")).to eq(false)
      end
    end
  end
end
