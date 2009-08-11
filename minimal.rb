# Pass NEW=1 to run with the new Base
ENV['RAILS_ENV'] ||= 'production'
ENV['NO_RELOAD'] ||= '1'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"
require 'action_controller'
require 'action_controller/new_base' if ENV['NEW']
require 'action_view'
require 'benchmark'

class Runner
  def initialize(app, output)
    @app, @output = app, output
  end

  def puts(*)
    super if @output
  end

  def call(env)
    env['n'].to_i.times { @app.call(env) }
    @app.call(env).tap { |response| report(env, response) }
  end

  def report(env, response)
    return unless ENV["DEBUG"]
    out = env['rack.errors']
    out.puts response[0], response[1].to_yaml, '---'
    response[2].each { |part| out.puts part }
    out.puts '---'
  end

  def self.puts(*)
    super if @output
  end

  def self.run(app, n, label, output = true)
    @output = output
    puts label, '=' * label.size if label
    env = Rack::MockRequest.env_for("/").merge('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
    t = Benchmark.realtime { new(app, output).call(env) }
    puts "%d ms / %d req = %.1f usec/req" % [10**3 * t, n, 10**6 * t / n]
    puts
  end
end


N = (ENV['N'] || 1000).to_i

module ActionController::Rails2Compatibility
  instance_methods.each do |name|
    remove_method name
  end
end

class BasePostController < ActionController::Base
  append_view_path "#{File.dirname(__FILE__)}/views"

  if ActionPack::VERSION::MAJOR > 2
    def overhead
      self.response_body = ''
    end
  end

  def index
    render :text => ''
  end

  $OBJECT = {:name => "Hello my name is omg", :address => "333 omg"}

  def partial
    render :partial => "/collection", :object => $OBJECT
  end

  def ten_partials
    render :partial => "/ten_partials"
  end

  def hundred_partials
    render :partial => "/hundred_partials"
  end

  $COLLECTION1 = []
  10.times do |i|
    $COLLECTION1[i] = {:name => "Hello my name is omg", :address => "333 omg"}
  end

  def collection_of_10
    render :partial => "/collection", :collection => $COLLECTION1
  end

  $COLLECTION2 = []
  100.times do |i|
    $COLLECTION2[i] = {:name => "Hello my name is omg", :address => "333 omg"}
  end

  def collection_of_100
    render :partial => "/collection", :collection => $COLLECTION2
  end

  def show_template
    render :template => "template"
  end
  
  module Foo
    def omg
      "omg"
    end
  end
  helper Foo
end

ActionController::Base.use_accept_header = false

unless ENV["PROFILE"]
  if ActionPack::VERSION::MAJOR > 2
    Runner.run(BasePostController.action(:overhead),        1, 'overhead',          false)
  end
  Runner.run(BasePostController.action(:index),             1, 'index',             false)
  Runner.run(BasePostController.action(:show_template),     1, 'template',          false)
  Runner.run(BasePostController.action(:partial),           1, 'partial',           false)
  Runner.run(BasePostController.action(:ten_partials),      1, 'ten_partials',      false)
  Runner.run(BasePostController.action(:collection_of_10),  1, 'collection_of_10',  false)
  Runner.run(BasePostController.action(:hundred_partials),  1, 'hundred_partials',  false)
  Runner.run(BasePostController.action(:collection_of_100), 1, 'collection_of_100', false)

  (ENV["M"] || 1).to_i.times do
  if ActionPack::VERSION::MAJOR > 2
    Runner.run(BasePostController.action(:overhead),        N, 'overhead',          true)
  end
  Runner.run(BasePostController.action(:index),             N, 'index',             true)
  Runner.run(BasePostController.action(:show_template),     N, 'template',          true)
  Runner.run(BasePostController.action(:partial),           N, 'partial',           true)
  Runner.run(BasePostController.action(:ten_partials),      N, 'ten_partials',      true)
  Runner.run(BasePostController.action(:collection_of_10),  N, 'collection_of_10',  true)
  Runner.run(BasePostController.action(:hundred_partials),  N, 'hundred_partials',  true)
  Runner.run(BasePostController.action(:collection_of_100), N, 'collection_of_100', true)
  end
else
  Runner.run(BasePostController.action(ENV["PROFILE"].to_sym), 1, ENV["PROFILE"], false)
  require "ruby-prof"
  RubyProf.start
  Runner.run(BasePostController.action(ENV["PROFILE"].to_sym), N, ENV["PROFILE"])
  result = RubyProf.stop
  printer = RubyProf::CallStackPrinter.new(result)
  printer.print(File.open("output.html", "w"))
end