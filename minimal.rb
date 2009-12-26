# Pass NEW=1 to run with the new Base
ENV['RAILS_ENV'] ||= 'production'
ENV['NO_RELOAD'] ||= '1'

# Needed for Rails 3. For Rails 2.3, it's easy enough to run off system gems
# since there are fewer dependencies
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../.."
require 'vendor/gems/environment'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../activemodel/lib"

require 'action_pack'
require 'action_controller'
require 'action_view'
require 'benchmark'

MyHash = Class.new(Hash)

if ActionPack::VERSION::MAJOR > 2
  require 'active_model'

  Hash.class_eval do
    extend ActiveModel::Naming
    include ActiveModel::Conversion
  end
end

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

  def partial_10
    render :partial => "/ten_partials"
  end

  def partial_100
    render :partial => "/hundred_partials"
  end

  $COLLECTION1 = []
  10.times do |i|
    $COLLECTION1 << { :name => "Hello my name is omg", :address => "333 omg" }
  end

  def coll_10
    render :partial => "/collection", :collection => $COLLECTION1
  end

  $COLLECTION2 = []
  100.times do |i|
    $COLLECTION2 << { :name => "Hello my name is omg", :address => "333 omg" }
  end

  def coll_100
    render :partial => "/collection", :collection => $COLLECTION2
  end

  def uniq_100
    render :partial => $COLLECTION2
  end

  $COLLECTION3 = []
  50.times do |i|
    $COLLECTION3 << {:name => "Hello my name is omg", :address => "333 omg"}
    $COLLECTION3 << MyHash.new(:name => "Hello my name is omg", :address => "333 omg")
  end

  def diff_100
    render :partial => $COLLECTION3
  end

  def template_1
    render :template => "template"
  end

  module Foo
    def omg
      "omg"
    end
  end
  helper Foo
end

N = (ENV['N'] || 1000).to_i
ActionController::Base.use_accept_header = false

def run_all!(times, verbose)
  if ActionPack::VERSION::MAJOR > 2
    Runner.run(:overhead, times, verbose)
  end
  Runner.run(:index,       times, verbose)
  Runner.run(:template_1,  times, verbose)
  Runner.run(:partial,     times, verbose)
  Runner.run(:partial_10,  times, verbose)
  Runner.run(:coll_10,     times, verbose)
  Runner.run(:partial_100, times, verbose)
  Runner.run(:coll_100,    times, verbose)
  Runner.run(:uniq_100,    times, verbose)
  Runner.run(:diff_100,    times, verbose)
end

unless ENV["PROFILE"]
  run_all!(1, false)

  (ENV["M"] || 1).to_i.times do
    $ran = []
    run_all!(N, true)
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