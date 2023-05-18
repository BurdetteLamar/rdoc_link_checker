# frozen_string_literal: true

require_relative 'lib/rdoc_link_checker/version'

Gem::Specification.new do |spec|
  spec.name = 'rdoc_link_checker'
  spec.version = RDocLinkChecker::VERSION
  spec.authors = ['Burdette Lamar']
  spec.email = ['burdettelamar@yahoo.com']

  spec.summary = 'Check links in RDoc output.'
  spec.homepage = 'https://github.com/BurdetteLamar/rdoc_link_checker'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = ''

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/BurdetteLamar/rdoc_link_checker'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[test/ .git])
    end
  end
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
