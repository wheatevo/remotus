# frozen_string_literal: true

# Assumes docker-compose is available

RSpec.describe "Remotus::SshConnection Integration Tests" do
  before(:all) do
    # docker-compose startup
    `docker-compose -f "docker-compose.yml" up -d --build`

    # Set up Remotus credentials based on Dockerfile
    Remotus::Auth.cache["localhost"] = Remotus::Auth::Credential.new("testuser", "testuser")
    Remotus::Auth.cache["target"] = Remotus::Auth::Credential.new("testuser", "testuser")

    # Allow time for sshd to start up
    sleep 1
  end

  after(:all) do
    # docker-compose cleanup
    `docker-compose -f "docker-compose.yml" down -v`
  end

  let(:test_script) { ::File.join(__dir__, "ssh_integration_script.sh") }
  let(:test_script_dest) { ::File.join("/home/testuser", ::File.basename(test_script)) }

  context "when a gateway and inaccessible target host exist" do
    let(:gateway_hostname) { `docker ps | grep remotus_gateway`.split.first }
    let(:target_hostname) { `docker ps | grep remotus_target`.split.first }
    let(:gateway_connection) { Remotus.connect("localhost", proto: :ssh, port: 2222) }
    let(:target_connection) { Remotus.connect("target", proto: :ssh, port: 22, gateway_host: "localhost", gateway_port: 2222) }

    it "Connects to the gateway host successfully" do
      expect(gateway_connection.run("hostname").stdout.chomp).to eq(gateway_hostname)
    end

    it "Can run a script against the gateway host successfully" do
      result = gateway_connection.run_script(test_script, test_script_dest)
      expect(result.stdout).to eq("success")
      expect(result.success?).to eq(true)
    end

    it "Can upload a file to the gateway host" do
      result = gateway_connection.upload(test_script, "/home/testuser/upload_test")
      expect(result).to eq("/home/testuser/upload_test")
      expect(gateway_connection.file_exist?("/home/testuser/upload_test")).to eq(true)
    end

    it "Can download a file from the gateway host" do
      gateway_connection.run('echo -n "test" > /home/testuser/download_test')
      result = gateway_connection.download("/home/testuser/download_test")
      expect(result).to eq("test")
    end

    it "Can check if a file exists on the gateway host" do
      expect(gateway_connection.file_exist?("/home/testuser")).to eq(true)
    end

    it "Connects to the target host successfully" do
      expect(target_connection.run("hostname").stdout.chomp).to eq(target_hostname)
    end

    it "Can run a script against the target host successfully" do
      result = target_connection.run_script(test_script, test_script_dest)
      expect(result.stdout).to eq("success")
      expect(result.success?).to eq(true)
    end

    it "Can upload a file to the target host" do
      result = target_connection.upload(test_script, "/home/testuser/upload_test")
      expect(result).to eq("/home/testuser/upload_test")
      expect(target_connection.file_exist?("/home/testuser/upload_test")).to eq(true)
    end

    it "Can download a file from the target host" do
      target_connection.run('echo -n "test" > /home/testuser/download_test')
      result = target_connection.download("/home/testuser/download_test")
      expect(result).to eq("test")
    end

    it "Can check if a file exists on the target host" do
      expect(target_connection.file_exist?("/home/testuser")).to eq(true)
    end
  end
end
