# frozen_string_literal: true

require "remotus"

module Remotus
  # Class to standardize remote output from WinRM and SSH connections
  class Result
    # @return [String] executed command
    attr_reader :command

    # @return [String] standard output
    attr_reader :stdout

    # @return [String] standard error output
    attr_reader :stderr

    # @return [String] all output (stdout and stderr interleaved)
    attr_reader :output

    # @return [Integer] exit code
    attr_reader :exit_code

    #
    # Creates a new Result
    #
    # @param [String] command command executed
    # @param [String] stdout standard output
    # @param [String] stderr standard error output
    # @param [String] output all output (stdout and stderr interleaved)
    # @param [Integer] exit_code exit code
    #
    def initialize(command, stdout, stderr, output, exit_code = nil)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @output = output
      @exit_code = exit_code
    end

    #
    # Alias for all interleaved stdout and stderr output
    #
    # @return [String] interleaved output
    #
    def to_s
      output
    end

    #
    # Whether an error was encountered
    #
    # @param [Array] accepted_exit_codes integer array of acceptable exit codes
    #
    # @return [Boolean] Whether an error was encountered
    #
    def error?(accepted_exit_codes = [0])
      !Array(accepted_exit_codes).include?(@exit_code)
    end

    #
    # Raises an exception if an error was encountered
    #
    # @param [Array] accepted_exit_codes integer array of acceptable exit codes
    #
    def error!(accepted_exit_codes = [0])
      return unless error?(accepted_exit_codes)

      raise Remotus::ResultError, "Error encountered executing #{@command}! Exit code #{@exit_code} was returned "\
        "while a value in #{accepted_exit_codes} was expected.\n#{output}"
    end

    #
    # Whether the command was successful
    #
    # @param [Array] accepted_exit_codes integer array of acceptable exit codes
    #
    # @return [Boolean] Whether the command was successful
    #
    def success?(accepted_exit_codes = [0])
      !error?(accepted_exit_codes)
    end
  end
end
