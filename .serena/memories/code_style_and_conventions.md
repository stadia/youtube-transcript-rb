# Code Style and Conventions

## Ruby Style
- All Ruby files start with `# frozen_string_literal: true`
- Uses standard Ruby 3.2+ features
- Module nesting: `Youtube::Transcript::Rb`

## Naming Conventions
- Classes: PascalCase (e.g., `YouTubeTranscriptApi`, `FetchedTranscript`)
- Methods: snake_case (e.g., `find_transcript`, `find_generated_transcript`)
- Constants: SCREAMING_SNAKE_CASE
- Files: snake_case matching class names

## Documentation
- Use YARD-style documentation comments
- `@param` for parameters
- `@return` for return values
- `@raise` for exceptions

## Testing
- RSpec for tests
- WebMock for HTTP stubbing
- Test files in `spec/` directory
- Naming: `*_spec.rb`

## Error Handling
- Custom exception classes inheriting from base `Error` class
- Exception hierarchy matching Python library structure:
  - `PoTokenRequired`
  - `TranscriptsDisabled`
  - `NoTranscriptFound`
  - `NoTranscriptAvailable`
  - `VideoUnavailable`
  - `TranslationLanguageNotAvailable`
  - `TooManyRequests`
