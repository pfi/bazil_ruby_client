require 'rubygems'
require 'json'
require 'bazil/model'

module Bazil
  class Application
    attr_reader :name

    def initialize(client, name)
      @client = client
      @http_cli = client.http_client
      @name = name

      status
    end

    def config
      res = @http_cli.get(gen_uri('config'))
      raise "Failed to get config of the application: application = #{@name}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def model_names
      res = @http_cli.get(gen_uri('models'))
      raise "Failed to get names of models: application = #{@name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      JSON.parse(res.body)['model_names']
    end

    def create_model(model_name, config_id, config = nil)
      raise "model_name has an invalid value: #{model_id}" if model_name.nil? or !model_name.kind_of?(String)
      raise "config_id has an invalid value: #{config_id}" if config_id.nil? or !config_id.kind_of?(String)

      config ||= {
        'model_type' => 'multi_class',
        'description' => 'multi-class model',
        'model_config' => {
          'method' => 'nherd',
          'description' => 'first  configuration',
          'config' => {
            "converter_config" => {
              "string_filter_types" => {},
              "string_filter_rules" => [],
              "num_filter_types" => {},
              "num_filter_rules" => [],
              "string_types" => {},
              "string_rules" => [
                {"key" => "*", "type" => "space", "sample_weight" => "bin", "global_weight" => "bin"}
              ],
              "num_types" => {},
              "num_rules" => [
                { "key" => "*",  "type" => "num" }
              ],
            },
            'classifier_config' => {
              'regularization_weight' => 0.2
            }
          }
        }
      }

      raise "model_config is missing: #{config.inspect}" unless config['model_config']

      config['model_name'] = model_name
      config['model_config']['id'] = config_id
      data = config.to_json
      res = @http_cli.post(gen_uri("models"), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "Failed to create a model: application = #{@name}, model = #{model_name}" unless res.code =~ /2[0-9][0-9]/
      Model.new(@client, self, model_name, config_id)
    end

    def delete_model(model_name)
      res = @http_cli.delete(gen_uri("models/#{model_name}"))
      raise "Failed to delete model: application = #{@name}, model = #{@model_name}" unless res.code =~ /2[0-9][0-9]/
      true # TODO: return better information
    end

    def model(model_name, default_config_id = nil)
      Model.new(@client, self, model_name, default_config_id)
    end

    def status
      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the application: #{@name}" unless res.code =~ /2[0-9][0-9]/
      # TODO: format result
      JSON.parse(res.body)
    end

    private
    def gen_uri(path = nil)
      if path
        "/#{@client.api_version}/apps/#{@name}/#{path}"
      else
        "/#{@client.api_version}/apps/#{@name}"
      end
    end
  end # class Application
end # module Bazil
