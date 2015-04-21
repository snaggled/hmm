require 'rubygems'
require 'shoulda'
gem 'test-unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'hmm'

class Test::Unit::TestCase
end
