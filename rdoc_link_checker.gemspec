lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rdoc_link_checker/version'

Gem::Specification.new do |spec|
  spec.name          = 'rdoc_link_checker'
  spec.version       = RDocLinkChecker::VERSION
  spec.authors       = ['burdettelamar']
  spec.email         = ['burdettelamar@yahoo.com']
  spec.summary       = 'Tool to check links in RDoc-generated HTML files.'
  spec.homepage      = 'https://github.com/BurdetteLamar/rdoc_link_checker'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
  #   spec.metadata['allowed_push_host'] = "http://rubygems.org"
  # else
  #   raise 'RubyGems 2.0 or newer is required to protect against ' \
  #     'public gem pushes.'
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = ['rdoc_link_checker']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 12.3.2'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
