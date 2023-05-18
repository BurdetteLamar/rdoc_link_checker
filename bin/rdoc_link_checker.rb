require 'getoptlong'
require_relative '../lib/rdoc_link_checker'

options = GetoptLong.new(
  ['--html_dirpath', '-d', GetoptLong::REQUIRED_ARGUMENT],
  ['--version', '-v', GetoptLong::NO_ARGUMENT],
  ['--help', '-h', GetoptLong::NO_ARGUMENT]
)

message = nil
case ARGV.size
when 0
  message = "Expected one argument; got none."
when 1
  # Okay.
else
  message = "Expected one argument, not #{ARGV.inspect}."
end
raise ArgumentError.new(message) if message

def help
  puts 'Boo!'
end

def version
  puts RDocLinkChecker::VERSION
end

options.each do |option, argument|
  case option
  when '--help'
    help
  when '--version'
    version
  end
end

html_dirpath = ARGV[0]
RDocLinkChecker.new(html_dirpath)