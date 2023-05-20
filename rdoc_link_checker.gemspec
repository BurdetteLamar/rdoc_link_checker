lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rdoc_link_checker/version'

Gem::Specification.new do |spec|
  spec.name          = 'rdoc_link_checker'
  spec.version       = RDocLinkChecker::VERSION
  spec.authors       = ['Burdette Lamar']
  spec.email         = ['burdettelamar@yahoo.com']
  spec.summary       = 'Tool to check links in RDoc-generated HTML files.'
  spec.homepage      = 'https://github.com/BurdetteLamar/rdoc_link_checker'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = ['rdoc_link_checker']
  spec.require_paths = ['lib']

  spec.metadata = {
    'bug_tracker_uri'   => 'https://github.com/BurdetteLamar/rdoc_link_checker/issues',
    'documentation_uri' => 'https://github.com/BurdetteLamar/rdoc_link_checker/blob/dev/README.md',
    'homepage_uri'      => 'https://github.com/BurdetteLamar/rdoc_link_checker',
  }

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 12.3.2'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
