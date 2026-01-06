# frozen_string_literal: true

require_relative "lib/youtube/transcript/rb/version"

Gem::Specification.new do |spec|
  spec.name = "youtube-transcript-rb"
  spec.version = Youtube::Transcript::Rb::VERSION
  spec.authors = ["jeff.dean"]
  spec.email = ["stadia@gmail.com"]

  spec.summary = "Fetch YouTube video transcripts and subtitles"
  spec.description = "A Ruby library to retrieve transcripts/subtitles for YouTube videos. Port of the Python youtube-transcript-api."
  spec.homepage = "https://github.com/stadia/youtube-transcript-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["bug_tracker_uri"] = "https://github.com/stadia/youtube-transcript-rb/issues"
  spec.metadata["documentation_uri"] = "https://github.com/stadia/youtube-transcript-rb#readme"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-follow_redirects", "~> 0.3"
  spec.add_dependency "nokogiri", "~> 1.15"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
