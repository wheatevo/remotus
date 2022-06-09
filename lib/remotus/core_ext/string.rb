# frozen_string_literal: true

module Remotus
  # Core Ruby extensions
  module CoreExt
    # String extension module
    module String
      unless method_defined?(:to_method_name)
        #
        # Converts a string into a safe method name that can be used for instance variables
        #
        # @return [Symbol] Method name
        #
        def to_method_name
          gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z])([A-Z])/, '\1_\2')
            .tr(" ", "_")
            .gsub(/(?:[^_a-zA-Z0-9]|^\d+)/, "")
            .downcase
            .to_sym
        end
      end
    end
  end
end

# @api private
# Core ruby string class
class String
  include Remotus::CoreExt::String
end
