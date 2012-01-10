require 'rubygems'
require 'json'
require 'bazil/model'

module Bazil
  class Application
    attr_reader :name

    def initialize(http_cli, name)
      @http_cli = http_cli
      @name = name

      status
    end

    def model_names
      res = @http_cli.get(gen_uri('models'))
      raise "Failed to get names of models: application = #{@name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      JSON.parse(res.body)['model_names']
    end

    def create_model(model_name, config)
      @@default_config = {
        "classifier_config" => {
          "method" => "nherd",
          "regularization_weight" => 1.0
        },
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
        }
      }

      config ||= {}
      config = @@default_config.merge(config) # TODO: implement recursive merge if necessary

      data = %({"model_name": "#{model_name}", "config": #{config.to_json}})
      res = @http_cli.post(gen_uri("models"), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "Failed to create a model: application = #{@name}, model = #{model_name}" unless res.code =~ /2[0-9][0-9]/
      Model.new(@http_cli, self, model_name)
    end

    def delete_model(model_name)
      res = @http_cli.delete(gen_uri("models/#{model_name}"))
      raise "Failed to delete model: application = #{@name}, model = #{@model_name}" unless res.code =~ /2[0-9][0-9]/
      true # TODO: return better information
    end

    def model(model_name)
      Model.new(@http_cli, self, model_name)
    end

    def status
      return # FIXME: current bazil_server doesn't have

      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the application: #{@name}" unless res.code =~ /2[0-9][0-9]/
      # TODO: format result
      if res.body == ""
        {}
      else
        JSON.parse(res.body)
      end
    end

    private
    def gen_uri(path = nil)
      if path
        "/apps/#{@name}/#{path}"
      else
        "/apps/#{@name}"
      end
    end
  end # class Application
end # module Bazil
