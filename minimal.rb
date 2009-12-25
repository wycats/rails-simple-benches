# Pass NEW=1 to run with the new Base
ENV['RAILS_ENV'] ||= 'production'
ENV['NO_RELOAD'] ||= '1'

# Needed for Rails 3. For Rails 2.3, it's easy enough to run off system gems
# since there are fewer dependencies
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../.."
require 'vendor/gems/environment'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"

require 'action_pack'
require 'action_controller'
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

  def self.print(*)
    super if @output
  end

  if ActionPack::VERSION::MAJOR < 3
    def self.app_and_env_for(action, n)
      env = Rack::MockRequest.env_for("/?action=#{action}")
      env.merge!('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
      app = BasePostController
      return app, env
    end
  else
    def self.app_and_env_for(action, n)
      env = Rack::MockRequest.env_for("/")
      env.merge!('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
      app = BasePostController.action(action)
      return app, env
    end
  end

  $ran = []

  def self.run(action, n, output = true)
    print "."
    STDOUT.flush
    @output = output
    label = action.to_s
    app, env = app_and_env_for(action, n)
    t = Benchmark.realtime { new(app, output).call(env) }
    $ran << [label, (t * 1000).to_i.to_s] if output
  end

  def self.done
    puts
    header, content = "", ""
    $ran.each do |k,v|
      size = [k.size, v.size].max + 1
      header << format("%#{size}s", k)
      content << format("%#{size}s", v)
    end
    puts header
    puts content
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
    Runner.run(:overhead, 1, false)
  end
  Runner.run(:index,             1, false)
  Runner.run(:show_template,     1, false)
  Runner.run(:partial,           1, false)
  Runner.run(:ten_partials,      1, false)
  Runner.run(:collection_of_10,  1, false)
  Runner.run(:hundred_partials,  1, false)
  Runner.run(:collection_of_100, 1, false)

  (ENV["M"] || 1).to_i.times do
  $ran = []
  if ActionPack::VERSION::MAJOR > 2
    Runner.run(:overhead, N, true)
  end
  Runner.run(:index,             N, true)
  Runner.run(:show_template,     N, true)
  Runner.run(:partial,           N, true)
  Runner.run(:ten_partials,      N, true)
  Runner.run(:collection_of_10,  N, true)
  Runner.run(:hundred_partials,  N, true)
  Runner.run(:collection_of_100, N, true)
  Runner.done
  end
else
  Runner.run(ENV["PROFILE"].to_sym, 1, false)
  require "ruby-prof"
  RubyProf.start
  Runner.run(ENV["PROFILE"].to_sym, N, true)
  result = RubyProf.stop
  printer = RubyProf::CallStackPrinter.new(result)
  printer.print(File.open("output.html", "w"))
end