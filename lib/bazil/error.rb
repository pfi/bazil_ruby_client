module Bazil
  class BazilError < RuntimeError
  end

  class APIError < BazilError
    attr_reader :errors

    def initialize(message, code, response)
      @message = message
      @code = code
      @errors = response['errors']
    end

    def inspect
      result = [@message]
      result += @errors.map { |error| "\t#{error['file']}(#{error['line']}) = #{error['message']}" }
      result.join("\n")
    end
  end
end
