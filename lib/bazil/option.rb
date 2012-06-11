require 'optparse'

module Bazil
  class Option
    attr_reader :parser, :configs, :target

    def initialize(command, default_configs = {})
      @command = command
      @configs = default_configs.dup
      @parser = OptionParser.new

      set_default_configs
      set_default_options
    end

    def parse(argv)
      if argv.include?('--help')
        @parser.program_name = "bazil #{@command} target"
        puts @parser.help
        exit
      end

      @target = scan_target(argv)
      @parser.parse(argv)
    end

    def has_option?(key)
      @configs.has_key?(key)
    end

    def []=(key, value)
      @configs[key.to_s] = value
    end

    def [](key)
      raise "'#{key}' not found in options" unless has_option?(key)

      @configs[key]
    end

    def method_missing(action, *args)
      action_key = action.to_s
      case
      when action_key.end_with?('=')
        __send__(:[]=, action_key.delete('='), *args)
      when action_key.end_with?('_given?')
        __send__(:has_option?, action_key[0..action_key.length - '_given?'.length - 1], *args)
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
      sep = <<EOS

Available targets:
  server         server configuration #{@command == 'import' ? "(NOTE: Not supported yet)" : ''}
  app            application configuration and training data
  model          model configuration and training data
  training_data  only training data

Common options:
EOS
      @parser.separator sep
      @parser.on('-h VAL', '--host', 'host of Bazil server') { |v| @configs[HOST_KEY] = v }
      @parser.on('-p VAL', '--port', 'port of Bazil server') { |v| @configs[PORT_KEY] = Integer(v) }
      # @parser.on('-f VAL', '--format', 'training data export format. Support formats are JSON and CSV(default is json)') { |v| @configs[FORMAT_KEY] = v }
      @parser.on('-a VAL', '--app', 'application name to process') { |v| @configs[APP_KEY] = v }
      @parser.on('-m VAL', '--model', 'model name to process') { |v| @configs[MODEL_KEY] = v }
    end

    AVAILABLE_TARGETS = ['server', 'app', 'model', 'training_data']

    def scan_target(argv)
      raise "target is missing" if argv.empty?

      target = argv.shift
      raise "Unsupported target: target = #{target}" unless AVAILABLE_TARGETS.include?(target)
      target
    end
  end
end
