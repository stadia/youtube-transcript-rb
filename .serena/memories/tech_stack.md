# Tech Stack

## Language
- Ruby (>= 3.2.0)

## Dependencies (Runtime)
- `faraday` (~> 2.0) - HTTP client library
- `faraday-follow_redirects` (~> 0.3) - Redirect handling for Faraday
- `nokogiri` (~> 1.15) - XML/HTML parsing

## Dependencies (Development/Test)
- `rake` (~> 13.0) - Task runner
- `rspec` (~> 3.0) - Testing framework
- `webmock` (~> 3.0) - HTTP request stubbing for tests
- `irb` - Interactive Ruby console

## Gem Structure
- Uses bundler gem conventions
- Gem name: `youtube-transcript-rb`
- Gemspec: `youtube-transcript-rb.gemspec`
