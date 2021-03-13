# frozen_string_literal: true

RSpec.describe Remotus::CoreExt::String do
  let(:data) do
    {
      "TestThisThing" => :test_this_thing,
      "123Invalid_start" => :invalid_start,
      "   many    spaces" => :___many____spaces,
      "OSThing" => :os_thing,
      "!@#$%^&*&()-=invalid_starting_characters" => :invalid_starting_characters,
      "Invalid!@#$%^&*()-=_Interior_chars" => :invalid_interior_chars
    }
  end

  describe "#to_method_name" do
    it "converts the string to a safe method name that can be used for instance variables" do
      data.each do |str, out|
        expect(str.to_method_name).to eq(out)
      end
    end
  end
end
