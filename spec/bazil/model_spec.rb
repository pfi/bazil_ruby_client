require 'bazil'
require 'net/http'
require 'rspec'

class FakeResponse
  attr_reader :code, :message, :body
  def initialize(code,message,body)
    @code = code
    @message = message
    @body = body
  end
end

class FakeClient
  attr_accessor :http_client
  def initialize
    @http_client = Object.new
  end
  def api_version
    'v2'
  end
end

describe Bazil::Client  do
  let(:client) { FakeClient.new }
  let(:model_id) { 42 }
  let(:config_id) { 184 }

  let(:status_path) { "/#{client.api_version}/models/#{model_id}/configs/#{config_id}/status" }
  let(:status_result) {
    {
      "num_features" => 0,
      "num_train_queries" => 0,
      "num_labels" => 0,
      "num_queries" => 0,
    }
  }

  let(:retrain_path) { "/#{client.api_version}/models/#{model_id}/configs/#{config_id}/retrain" }
  let(:retrain_result) {
    {
      "total" => 1000,
      "elapsed_time" => 0.5,
    }
  }

  let(:query_path) { "/#{client.api_version}/models/#{model_id}/configs/#{config_id}/query" }
  let(:query_result) {
    {
      "score" => {
        "Label1" => 0.5,
        "Label2" => -0.5,
      },
      "classifier_result" => "Label1",
    }
  }

  let(:trace_path) { "/#{client.api_version}/models/#{model_id}/configs/#{config_id}/trace" }
  let(:trace_result) {
    {
      "result" => {
        "Label1" => 0.5,
        "Label2" => -0.5,
        "feature_weights" => {
          "Label1" => {
            "key" => {
              "string_weights" => [ [ 0.5, 0, 2 ] ]
            }
          },
          "Label2" => {
            "key" => {
              "string_weights" => [ [ -0.5, 0, 2 ] ]
            }
          }
        }
      },
      "data" => {
        "key" => "value"
      }
    }
  }

  let(:evaluate_path) { "/#{client.api_version}/models/#{model_id}/configs/#{config_id}/evaluate" }
  let(:evaluate_result) {
    # evaluate result is too much complex and different result among multi_class and multi_label
    {
      "folds" => [{},{}],
      "result" => {},
    }
  }

  def header_for_json(js)
    {
      "Content-Type" => "application/json; charset=UTF-8",
      "Content-Length" => js.to_json.length.to_s
    }
  end

  it "check status at initialize" do
    client.http_client.should_receive(:get).with(status_path).and_return(FakeResponse.new("200","OK",status_result.to_json))
    model = Bazil::Model.new(client, model_id, config_id)
  end

  let(:model) {
    client.http_client.should_receive(:get).with(status_path).and_return(FakeResponse.new("200","OK",status_result.to_json))
    Bazil::Model.new(client, model_id, config_id)
  }

  describe "model" do
    it "send get request at status" do
      client.http_client.should_receive(:get).with(status_path).and_return(FakeResponse.new("200","OK",status_result.to_json))
      expect(model.status).to eq(status_result)
    end

    it "send post request at retrain without argument" do
      arg = {}
      client.http_client.should_receive(:post).with(retrain_path, arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200","OK",retrain_result.to_json))
      expect(model.retrain).to eq(retrain_result)
    end

    it "send post request at retrain with times argument" do
      arg = {times: 10}
      client.http_client.should_receive(:post).with(retrain_path, arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200","OK",retrain_result.to_json))
      expect(model.retrain(arg)).to eq(retrain_result)
    end

    it "send post request at query" do
      arg = {data: {key: "value"}}
      client.http_client.should_receive(:post).with(query_path, arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200","OK",retrain_result.to_json))
      expect(model.query(arg[:data])).to eq(retrain_result)
    end

    it "send post request at trace" do
      arg = {method: "feature_weights", data: {key: "value"}}
      client.http_client.should_receive(:post).with(trace_path, arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200","OK",trace_result.to_json))
      expect(model.trace(arg[:method], arg[:data])).to eq(trace_result)
    end

    it "send post request at evaluate" do
      arg = {method: "cross_validation", config: {num_folds: 2}}
      client.http_client.should_receive(:post).with(evaluate_path, arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200","OK",evaluate_result.to_json))
      expect(model.evaluate(arg[:method], arg[:config])).to eq(evaluate_result)
    end
  end
end
