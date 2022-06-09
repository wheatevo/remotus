# frozen_string_literal: true

RSpec.describe Remotus::CoreExt::Elevated do
  let(:connection_opts) do
    {
      user: "username",
      password: "password",
      domain: "domain_name"
    }
  end

  let(:winrm_elevated_connection) do
    double(WinRM::Connection, shell: double(WinRM::Shells::Elevated), connection_opts: connection_opts)
  end

  describe "#connection_opts" do
    it "returns connection_opts object" do
      expect(winrm_elevated_connection.connection_opts).to eq(connection_opts)
    end
  end
end
