# frozen_string_literal: true

require "winrm-elevated"

module Remotus
  # Core Ruby extensions
  module CoreExt
    # WinRM Elevated extension module
    module Elevated
      unless method_defined?(:connection_opts)
        #
        # Returns a hash for the connection options from the interal
        # WinRM::Shells::Powershell object
        #
        # @return [Hash] internal WinRM::Shells::Powershell connection options
        #
        def connection_opts
          @shell.connection_opts
        end
      end
    end
  end
end

# @api private
# Main WinRM module
module WinRM
  # Shells module (contains PowerShell, Elevated, etc.)
  module Shells
    # Elevated PowerShell class from winrm-elevated
    class Elevated
      include Remotus::CoreExt::Elevated
    end
  end
end
