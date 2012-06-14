module Bazil
  class BazilError < RuntimeError
  end

  class ConnectionError < BazilError
    attr_reader :method, :address, :port

    def initialize(method, address, port)
      @method = method
      @address = address
      @port = port
    end

    def inspect
      "Failed to connect to the server at #{@method} method: server = #{@address}:#{@port}"
    end
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
