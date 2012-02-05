require 'rubygems'
require 'json'

module Bazil
  class Model
    attr_reader :application, :name

    def initialize(http_cli, app, name)
      @http_cli = http_cli
      @application = app
      @name = name

      status
    end

    def status
      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    # TODO: config
    # TODO: retrain
    # TODO: label APIs

    def train(label, data)
      data = %({"label": "#{label}", "data": #{data.to_json}})
      body = post('training_data', data, "Failed to post training data")
      JSON.parse(body)
    end

    def training_data(id)
      res = @http_cli.get(gen_uri("training_data/#{id}"))
      raise "Failed to get training data of the model: id = #{id}, #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def list_training_data(condition)
      # TODO: validate parameter
      condition[:page] ||= 1
      condition[:pagesize] ||= 10
      if condition.has_key?(:query)
        res = post("training_data/query?page=#{condition[:page]}&pagesize=#{condition[:pagesize]}",
                   condition[:query].to_json, "Failed to query training data of the model")
        # TODO: query API does not support page/pagesize yet,
        # so this client manually emulates it. Remove this code
        # after bazil_server supported page/pagesize.
        res = JSON.parse(res)
        len = condition[:pagesize]
        start = (condition[:page] - 1) * len
        res['training_data'] = res['training_data'][start...(start + len)]
        res['training_data'] = [] unless res['training_data']
        res
      else
        res = @http_cli.get(gen_uri("training_data?page=#{condition[:page]}&pagesize=#{condition[:pagesize]}"))
        raise "Failed to get training data of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
        JSON.parse(res.body)
      end
    end

    def clear_training_data
      res = @http_cli.delete(gen_uri("training_data"))
      raise "Failed to clear training_data of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def put_training_data(data)
      data = %({"data": #{data.to_json}})
      body = post('training_data', data, "Failed to post training data")
      JSON.parse(body)
    end

    def query(data)
      data = data.to_json
      res = JSON.parse(post('query', data, "Failed to post data for query"))
      return res['max_label'], res
    end

    private
    def post(path, data, error_message)
      res = @http_cli.post(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "#{error_message}: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def gen_uri(path = nil)
      if path
        "/apps/#{@application.name}/models/#{@name}/#{path}"
      else
        "/apps/#{@application.name}/models/#{@name}"
      end
    end

    def error_suffix
      "application = #{@application.name}, model = #{@name}"
    end
  end # module Model
end # module Bazil
