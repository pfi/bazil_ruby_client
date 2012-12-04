$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib'))

require 'rubygems'
#require 'dtest'
require 'mongo'

fail "MONGODB_SERVERS is missing" unless ENV.has_key?("MONGODB_SERVERS")

CONFIG_PATH = File.join(File.dirname(__FILE__), 'config.json')
BIN_PATH = ENV.has_key?('BAZIL_DEV_SERVER') ? ENV['BAZIL_DEV_SERVER'] : File.join(ENV['BAZIL_HOME'], 'bin', 'bazil_server')

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

def restart_bazil
  Process.kill('SIGKILL', $BAZIL_PID)
  delete_files(File.join(EXPORT_DIR, "#{APP_NAME}-"))
  sleep 1
  $BAZIL_PID = start_bazil(BAZIL_PORT)
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

$BAZIL_PID = nil
MONGODB_SERVERS = ENV["MONGODB_SERVERS"]
BAZIL_PORT = unused_port
APP_NAME = 'bazil_test'
EXPORT_DIR = File.join(ENV['BAZIL_HOME'], 'export')

GlobalHarness do
  before do
    delete_files(File.join(EXPORT_DIR, "#{APP_NAME}-"))
    host, port = MONGODB_SERVERS.split(':')
    Mongo::Connection.new(host, port).drop_database("bazil")
    Mongo::Connection.new(host, port).drop_database("bazil-#{APP_NAME}")

    $BAZIL_PID = start_bazil(BAZIL_PORT)
  end

  after do
    Process.kill('SIGKILL', $BAZIL_PID)
    delete_files(File.join(EXPORT_DIR, "#{APP_NAME}-"))

    host, port = MONGODB_SERVERS.split(':')
    Mongo::Connection.new(host, port).drop_database(APP_NAME)
    Mongo::Connection.new(host, port).drop_database("bazil-#{APP_NAME}")
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
    set :client, Bazil::Client.new(host, port, {disable_ssl: true})

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
end

SharedContext 'bazil_model_utils' do # require bazil_case_utils
  def create_random_model
    set :model_name, 'random'
    set :model_config_id, 'saitama'
    set :model_config, {
      'model_type' => 'multi_class',
      'description' => 'application test',
      'model_config' => {
        'id' => model_config_id,
        'method' => 'nherd',
        'description' => 'saitama configuration',
        'config' => {
          'converter_config' => JSON.parse(File.read(CONFIG_PATH)),
          'classifier_config' => {
            'regularization_weight' => 0.2
          }
        }
      }
    }

    # Remove previous training data
    c = Mongo::Connection.new(*MONGODB_SERVERS.split(':'))
    c.db('bazil').drop_collection('models')
    c.db('bazil').drop_collection('model_config')
    c.db("bazil-#{app_name}").drop_collection(model_name)

    app.create_model(model_name, model_config_id, model_config)
    set :model, app.model(model_name, model_config_id)
  end

  def delete_random_model
    app.delete_model(model_name)
  end

  def get_training_data_size
    model.list_training_data({})['training_data'].size
  end
end

SharedContext 'model_train_and_query_api' do
  def gen_data(algorithm)
    sample = gen_random_distribution(algorithm)
    train_data = sample[0...1000]
    classify_data = sample[1000..-1]
    [train_data, classify_data]
  end

  def rand_normal(mu, sigma)
    alpha = rand
    beta = rand
    mu + Math.sqrt(-2 * Math.log(alpha)) * Math.sin(2 * Math::PI * beta) * sigma
  end

  def make_random(mus, sigma, dim)
    [].tap { |a|
      dim.times { |i|
        a << rand_normal(mus[i % mus.size], sigma)
      }
    }
  end

  def gen_random_data
    if rand(2) == 0
      annotation = "OK"
      mu = 1.0
    else
      annotation = "NG"
      mu = -1.0
    end
    [annotation, make_random([mu], 1.0, 10)]
  end

  def naive_array_rotate(a, c)
    c %= a.size
    a[c..-1].to_a + a[0...c].to_a
  end

  def gen_random_data3
    i = rand(3)
    [["1", "2", "3"][i], make_random(naive_array_rotate([3, 0, -3], i), 1.0, 10)]
  end

  def gen_random_distribution(algorithm)
    if algorithm == "random"
      [].tap { |a|
        1100.times {
          annotation, data = gen_random_data
          a << {'annotation' => annotation, 'data' => {}.tap { |m| data.each_with_index { |d, i| m["f#{i}"] = d }}}
        }
      }
    else
      [].tap { |a|
        1100.times {
          annotation, data = gen_random_data3
          a << {'annotation' => annotation, 'data' => {}.tap { |m| data.each_with_index { |d, i| m["f#{i}"] = d }}}
        }
      }
    end
  end

  def classify(classify_data)
    collect_result = 0
    classify_data.each { |random_data|
      max_label, = model.query(random_data['data'])
      collect_result +=1 if random_data['annotation'] == max_label
    }
    collect_result
  end
end
