$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib'))

require 'rubygems'
require 'dtest'
require 'mongo'

fail "MONGODB_SERVERS is missing" unless ENV.has_key?("MONGODB_SERVERS")

CONFIG_PATH = File.join(File.dirname(__FILE__), 'config.json')
BIN_PATH = File.join(ENV['BAZIL_HOME'], 'bin', 'bazil_server')

def get_bazil_pids()
  user = `whoami`.strip
  `pgrep -u #{user} bazil_server`.split.map(&:to_i)
end

def start_bazil(port)
  ENV["GLOG_logtostderr"] = "1" # avoid creating log files
  pid = fork { exec("#{BIN_PATH} --config_servers #{MONGODB_SERVERS} --port #{port} --num_threads #{3}") }
  # TODO: Check server start using network access(ping or net/http)
  sleep 3
  pid
end

def unused_port
  require 'socket'

  s = TCPServer.open(0)
  port = s.addr[1]
  s.close
  port
end

def delete_dir(target_dir)
  Dir::glob(target_dir + "**/").sort { |a, b|
    b.split('/').size <=> a.split('/').size
  }.each { |d|
    Dir.foreach(d) { |f|
      File.delete(d + f) unless /\.+$/ =~ f
    }
    Dir::rmdir(d)
  }
end

def delete_files(prefix)
  Dir::glob("#{prefix}*") { |path|
    File.delete(path)
  }
end

MONGODB_SERVERS = ENV["MONGODB_SERVERS"]
BAZIL_PORT = unused_port
APP_NAME = 'bazil_test'
EXPORT_DIR = File.join(ENV['BAZIL_HOME'], 'export')

GlobalHarness do
  before do
    delete_files(File.join(EXPORT_DIR, "#{APP_NAME}-"))
    BAZIL_PID = start_bazil(BAZIL_PORT)
  end

  after do
    Process.kill('SIGKILL', BAZIL_PID)
    delete_files(File.join(EXPORT_DIR, "#{APP_NAME}-"))

    host, port = MONGODB_SERVERS.split(':')
    Mongo::Connection.new(host, port).drop_database(APP_NAME)
    Mongo::Connection.new(host, port).drop_database("bazil_#{APP_NAME}")
  end
end

require 'enumerator'

class Array
  def repeated_combination(num)
    return to_enum(:repeated_combination, num) unless block_given?
    #num = Backports.coerce_to_int(num)
    if num <= 0
      yield [] if num == 0
    else
      indices = Array.new(num, 0)
      indices[-1] = size
      while dec = indices.find_index(&:nonzero?)
        indices[0..dec] = Array.new dec+1, indices[dec] - 1
        yield values_at(*indices)
      end
    end
    self
  end unless method_defined? :repeated_combination

  def repeated_permutation(num)
    return to_enum(:repeated_permutation, num) unless block_given?
    #num = Backports.coerce_to_int(num)
    if num <= 0
      yield [] if num == 0
    else
      indices = Array.new(num, 0)
      indices[-1] = size
      while dec = indices.find_index(&:nonzero?)
        indices[0...dec] = Array.new dec, size - 1
        indices[dec] -= 1
        yield values_at(*indices)
      end
    end
    self
  end unless method_defined? :repeated_permutation
end

SharedContext 'bazil_case_utils' do
  def setup_environment
    set :host, 'localhost'
    set :port, BAZIL_PORT
    set :client, Bazil::Client.new(host, port)

    set :version, "/v1"
    set :app_name, APP_NAME
  end

  def cleanup_environment
    client.delete_all_applications
  end

  def create_default_application
    set :app, client.create_application(app_name)
  end

  def delete_default_application
    client.delete_application(app_name)
  end

  def create_random_model
    set :model_name, 'random'
    set :model_config, {
      'converter_config' => JSON.parse(File.read(CONFIG_PATH)),
      'classifier_config' => {
        'method' => 'nherd',
        'regularization_weight' => 0.2
      }
    }

    # Remove previous training data
    Mongo::Connection.new(*MONGODB_SERVERS.split(':')).db("bazil_#{app_name}").drop_collection(model_name)
    app.create_model(model_name, model_config)
    set :model, app.model(model_name)
  end

  def delete_random_model
    app.delete_model(model_name)
  end
end
