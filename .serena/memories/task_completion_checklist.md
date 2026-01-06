# Task Completion Checklist

When completing a task on this project, ensure:

## Before Committing
1. Run tests: `bundle exec rspec`
2. Ensure all tests pass
3. Check for syntax errors by loading the gem: `bundle exec ruby -e "require 'youtube/transcript/rb'"`

## Code Quality
- Add `# frozen_string_literal: true` to all new Ruby files
- Follow existing naming conventions
- Add YARD documentation for public methods
- Handle errors appropriately with custom exception classes

## Testing
- Add/update specs for new functionality
- Use WebMock to stub HTTP requests
- Test both success and error cases

## Python Library Alignment
When porting features, refer to the original Python library:
https://github.com/jdepoix/youtube-transcript-api

Ensure API compatibility where possible for a similar developer experience.
