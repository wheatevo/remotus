# frozen_string_literal: true

module Remotus
  module Auth
    # Authentication store base class
    class Store
      #
      # Base method fo retrieving a credential from the hash store.
      # This must be overridden in derived classes or it will raise an exception.
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] _connection unused associated connection
      # @param [Hash] _options unused options hash
      #
      def credential(_connection, **_options)
        raise Remotus::MissingOverride, "credential method not implemented in credential store #{self.class}"
      end

      #
      # Gets the user for a given connection and options
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection associated connection
      # @param [Hash] options options hash
      #
      # @return [String] user
      #
      def user(connection, **options)
        credential(connection, **options)&.user
      end

      #
      # Gets the password for a given connection and options
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection associated connection
      # @param [Hash] options options hash
      #
      # @return [String] password
      #
      def password(connection, **options)
        credential(connection, **options)&.password
      end
    end
  end
end
