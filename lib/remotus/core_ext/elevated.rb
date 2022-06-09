# frozen_string_literal: true

require "winrm-elevated"

module Remotus
  # Core Ruby extensions
  module CoreExt
    # Elevated extension module
    module Elevated
      unless method_defined?(:connection_opts)
        #
        #  Returns a hash into a safe method name that can be used for instance variables
        #
        # @return [Hash] Method name
        #
        def connection_opts
          @shell.connection_opts
        end
      end
    end
  end
end

WinRM::Shells::Elevated.include(Remotus::CoreExt::Elevated)
