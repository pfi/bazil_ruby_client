require 'optparse'

module Bazil
  class Option
    attr_reader :parser, :configs, :target

    def initialize(default_configs = {})
      @configs = default_configs.dup
      @parser = OptionParser.new

      set_default_configs
      set_default_options
    end

    def parse(argv)
      @target = scan_target(argv)
      @parser.parse(argv)
    end

    def []=(key, value)
      @configs[key.to_s] = value
    end

    def [](key)
      raise "'#{key}' not found in option" unless @configs.has_key?(key)

      @configs[key]
    end

    def method_missing(action, *args)
      action_key = action.to_s
      if action_key.end_with?('=')
        __send__(:[]=, action_key.delete('='), *args)
      else  
        __send__(:[], action_key)
      end
    end

    private

    HOST_KEY = 'host'
    PORT_KEY = 'port'
    FORMAT_KEY = 'format'
    APP_KEY = 'app'
    MODEL_KEY = 'model'

    def set_default_configs
      @configs[HOST_KEY] = 'localhost'
      @configs[PORT_KEY] = 8192
      @configs[FORMAT_KEY] = 'json'
    end

    def set_default_options
      @parser.on('-h VAL', '--host') { |v| @configs[HOST_KEY] = v }
      @parser.on('-p VAL', '--port') { |v| @configs[PORT_KEY] = Integer(v) }
      @parser.on('-f VAL', '--format') { |v| @configs[FORMAT_KEY] = v }
      @parser.on('-a VAL', '--app') { |v| @configs[APP_KEY] = v }
      @parser.on('-m VAL', '--model') { |v| @configs[MODEL_KEY] = v }
    end

    AVAILABLE_TARGETS = ['all', 'server', 'app', 'model', 'training_data']

    def scan_target(argv)
      raise "target is missing" if argv.empty?

      target = argv.shift
      raise "Unsupported target: target = #{target}" unless AVAILABLE_TARGETS.include?(target)
      target
    end
  end
end
