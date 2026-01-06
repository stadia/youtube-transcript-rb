# YouTube Transcript Ruby - Porting Plan

This document outlines the plan for porting the Python [youtube-transcript-api](https://github.com/jdepoix/youtube-transcript-api) library to Ruby.

## Overview

The Python library provides functionality to:
- Fetch transcripts/subtitles from YouTube videos
- Support for auto-generated and manually created captions
- Language preference selection
- Translation support
- Multiple output formatters
- Proxy support for IP ban workarounds

## Source Analysis

### Python Library Structure

```
youtube_transcript_api/
├── __init__.py
├── _api.py              # YouTubeTranscriptApi class
├── _transcripts.py      # Transcript, TranscriptList, FetchedTranscript, TranscriptListFetcher
├── _errors.py           # Exception classes
├── _settings.py         # Constants (URLs, API settings)
├── formatters.py        # Output formatters (JSON, SRT, WebVTT, Text, PrettyPrint)
└── proxies.py           # Proxy configuration classes
```

### Target Ruby Structure

```
lib/youtube/transcript/rb/
├── version.rb           # ✅ Already exists
├── errors.rb            # ✅ Completed (Phase 1)
├── settings.rb          # ✅ Completed (Phase 1)
├── transcript.rb        # ✅ Completed (Phase 1)
├── transcript_list.rb   # ❌ To be created
├── transcript_list_fetcher.rb  # ❌ To be created
├── transcript_parser.rb # ✅ Completed (Phase 1)
├── api.rb               # ❌ To be created (YouTubeTranscriptApi)
├── formatters.rb        # ❌ To be created
└── proxies.rb           # ❌ To be created (optional, Phase 5)
```

---

## Phase 1: Core Infrastructure

### Task 1.1: Create Error Classes (`errors.rb`)

**Priority:** High  
**Estimated Effort:** 1 hour

Create exception hierarchy mirroring Python's `_errors.py`:

```ruby
module Youtube::Transcript::Rb
  class Error < StandardError; end
  
  class CouldNotRetrieveTranscript < Error
    attr_reader :video_id
  end
  
  # Specific errors
  class VideoUnavailable < CouldNotRetrieveTranscript; end
  class TranscriptsDisabled < CouldNotRetrieveTranscript; end
  class NoTranscriptFound < CouldNotRetrieveTranscript; end
  class NoTranscriptAvailable < CouldNotRetrieveTranscript; end
  class TranslationLanguageNotAvailable < CouldNotRetrieveTranscript; end
  class NotTranslatable < CouldNotRetrieveTranscript; end
  class TooManyRequests < CouldNotRetrieveTranscript; end
  class IpBlocked < CouldNotRetrieveTranscript; end
  class RequestBlocked < CouldNotRetrieveTranscript; end
  class InvalidVideoId < CouldNotRetrieveTranscript; end
  class AgeRestricted < CouldNotRetrieveTranscript; end
  class VideoUnplayable < CouldNotRetrieveTranscript; end
  class PoTokenRequired < CouldNotRetrieveTranscript; end
  class YouTubeDataUnparsable < CouldNotRetrieveTranscript; end
  class YouTubeRequestFailed < CouldNotRetrieveTranscript; end
  class FailedToCreateConsentCookie < CouldNotRetrieveTranscript; end
end
```

### Task 1.2: Create Settings/Constants (`settings.rb`)

**Priority:** High  
**Estimated Effort:** 15 minutes

```ruby
module Youtube::Transcript::Rb
  WATCH_URL = "https://www.youtube.com/watch?v=%{video_id}"
  INNERTUBE_API_URL = "https://www.youtube.com/youtubei/v1/player?key=%{api_key}"
  INNERTUBE_CONTEXT = {
    "client" => {
      "clientName" => "ANDROID",
      "clientVersion" => "20.10.38"
    }
  }.freeze
end
```

### Task 1.3: Create Transcript Data Classes (`transcript.rb`)

**Priority:** High  
**Estimated Effort:** 1.5 hours

Classes to create:
- `TranscriptSnippet` - Individual transcript segment (text, start, duration)
- `FetchedTranscript` - Collection of snippets with metadata (Enumerable)
- `Transcript` - Metadata about available transcript with `fetch` and `translate` methods
- `TranslationLanguage` - Language code and name pair

Key Ruby idioms:
- Use `Struct` or plain classes with `attr_reader`
- Include `Enumerable` for `FetchedTranscript`
- Use keyword arguments for initialization

---

## Phase 2: Transcript Fetching

### Task 2.1: Create TranscriptParser (`transcript_parser.rb`)

**Priority:** High  
**Estimated Effort:** 1 hour

Parses XML transcript data from YouTube:
- Use Nokogiri for XML parsing
- Handle HTML entity unescaping
- Support `preserve_formatting` option
- Handle formatting tags (strong, em, b, i, etc.)

### Task 2.2: Create TranscriptListFetcher (`transcript_list_fetcher.rb`)

**Priority:** High  
**Estimated Effort:** 3 hours

This is the most complex component. Responsibilities:
1. Fetch video HTML page
2. Extract INNERTUBE_API_KEY from HTML
3. Make POST request to Innertube API
4. Parse captions JSON from response
5. Handle consent cookies
6. Handle various error conditions

Key methods:
- `fetch(video_id)` → `TranscriptList`
- `_fetch_video_html(video_id)`
- `_extract_innertube_api_key(html)`
- `_fetch_innertube_data(video_id, api_key)`
- `_extract_captions_json(innertube_data)`
- `_assert_playability(status_data)`

HTTP handling:
- Use Faraday for HTTP requests
- Set `Accept-Language: en-US` header
- Handle 429 (Too Many Requests) errors
- Handle consent cookie flow

### Task 2.3: Create TranscriptList (`transcript_list.rb`)

**Priority:** High  
**Estimated Effort:** 1.5 hours

Factory and container for transcripts:
- `TranscriptList.build(http_client, video_id, captions_json)`
- Store manually created and generated transcripts separately
- `find_transcript(language_codes)`
- `find_manually_created_transcript(language_codes)`
- `find_generated_transcript(language_codes)`
- Include `Enumerable`
- Implement `to_s` for debugging

---

## Phase 3: Main API

### Task 3.1: Create YouTubeTranscriptApi (`api.rb`)

**Priority:** High  
**Estimated Effort:** 1 hour

Main entry point class:
```ruby
class YouTubeTranscriptApi
  def initialize(http_client: nil, proxy_config: nil)
    # Setup Faraday connection
  end
  
  def fetch(video_id, languages: ["en"], preserve_formatting: false)
    list(video_id)
      .find_transcript(languages)
      .fetch(preserve_formatting: preserve_formatting)
  end
  
  def list(video_id)
    @fetcher.fetch(video_id)
  end
end
```

### Task 3.2: Update Main Module (`rb.rb`)

**Priority:** High  
**Estimated Effort:** 30 minutes

Update existing `lib/youtube/transcript/rb.rb`:
- Add all require statements
- Verify convenience methods work correctly
- Export all public classes

---

## Phase 4: Formatters

### Task 4.1: Create Formatter Classes (`formatters.rb`)

**Priority:** Medium  
**Estimated Effort:** 2 hours

Formatter hierarchy:
```ruby
module Formatters
  class Formatter  # Base class
    def format(transcript); raise NotImplementedError; end
    def format_transcripts(transcripts); raise NotImplementedError; end
  end
  
  class TextFormatter < Formatter; end
  class JSONFormatter < Formatter; end
  class PrettyPrintFormatter < Formatter; end
  class WebVTTFormatter < Formatter; end
  class SRTFormatter < Formatter; end
end
```

Timestamp formatting:
- WebVTT: `HH:MM:SS.mmm`
- SRT: `HH:MM:SS,mmm` (comma instead of period)

---

## Phase 5: Proxy Support (Optional)

### Task 5.1: Create Proxy Configuration (`proxies.rb`)

**Priority:** Low  
**Estimated Effort:** 1.5 hours

```ruby
class ProxyConfig
  def to_faraday_options; raise NotImplementedError; end
end

class GenericProxyConfig < ProxyConfig
  def initialize(http_url: nil, https_url: nil); end
end

class WebshareProxyConfig < GenericProxyConfig
  def initialize(proxy_username:, proxy_password:, **options); end
end
```

---

## Phase 6: Testing

### Task 6.1: Unit Tests for Each Component

**Priority:** High  
**Estimated Effort:** 4 hours

Test files to create/update:
- `spec/errors_spec.rb`
- `spec/transcript_spec.rb`
- `spec/transcript_list_spec.rb`
- `spec/transcript_list_fetcher_spec.rb`
- `spec/youtube_transcript_api_spec.rb` (already exists, expand)
- `spec/formatters_spec.rb` (already exists, expand)

Use WebMock for HTTP stubbing (already configured).

### Task 6.2: Integration Tests

**Priority:** Medium  
**Estimated Effort:** 2 hours

Create integration tests with real YouTube video IDs (skipped by default):
```ruby
RSpec.describe "Integration", :integration do
  it "fetches real transcript" do
    skip "Integration test - run manually"
    # ...
  end
end
```

---

## Implementation Order

### Week 1: Core Implementation

| Day | Task | Files |
|-----|------|-------|
| 1 | Task 1.1, 1.2 | `errors.rb`, `settings.rb` |
| 2 | Task 1.3 | `transcript.rb` |
| 3 | Task 2.1 | `transcript_parser.rb` |
| 4-5 | Task 2.2 | `transcript_list_fetcher.rb` |

### Week 2: API and Formatters

| Day | Task | Files |
|-----|------|-------|
| 1 | Task 2.3 | `transcript_list.rb` |
| 2 | Task 3.1, 3.2 | `api.rb`, update `rb.rb` |
| 3 | Task 4.1 | `formatters.rb` |
| 4-5 | Task 6.1 | All spec files |

### Week 3: Polish and Optional Features

| Day | Task | Files |
|-----|------|-------|
| 1-2 | Task 5.1 | `proxies.rb` |
| 3 | Task 6.2 | Integration tests |
| 4-5 | Documentation, README updates, bug fixes |

---

## Technical Decisions

### Ruby Idioms

| Python | Ruby |
|--------|------|
| `dataclass` | Plain class with `attr_reader` or `Struct` |
| `typing.Optional` | Sorbet/RBS types (optional) or YARD docs |
| `List[T]` | `Array` |
| `Dict[K, V]` | `Hash` |
| `requests.Session` | `Faraday::Connection` |
| `defusedxml.ElementTree` | `Nokogiri::XML` |
| `html.unescape` | `CGI.unescapeHTML` or Nokogiri |
| `re.compile` | `Regexp.new` |
| `json.dumps` | `JSON.generate` or `.to_json` |

### Error Message Compatibility

Keep error messages similar to Python version for easier debugging and user familiarity.

### HTTP Client

Use Faraday with:
- `faraday-follow_redirects` for redirect handling
- Connection pooling for multiple requests
- Configurable timeout

---

## Dependencies

Already in gemspec:
- `faraday` (~> 2.0) - HTTP client
- `faraday-follow_redirects` (~> 0.3) - Redirect handling
- `nokogiri` (~> 1.15) - XML/HTML parsing

Standard library (no additional gems needed):
- `json` - JSON parsing/generation
- `cgi` - HTML unescaping
- `uri` - URL handling

---

## API Compatibility Goals

The Ruby API should feel natural to Ruby developers while maintaining conceptual compatibility with the Python version:

```ruby
# Python
api = YouTubeTranscriptApi()
transcript = api.fetch("video_id", languages=["en"])

# Ruby (target)
api = Youtube::Transcript::Rb::YouTubeTranscriptApi.new
transcript = api.fetch("video_id", languages: ["en"])

# Ruby (convenience)
transcript = Youtube::Transcript::Rb.fetch("video_id", languages: ["en"])
```

---

## Known Limitations

1. **PO Token Requirement** - As of January 2026, YouTube requires PO tokens for some videos. This affects all transcript libraries.

2. **Cookie Authentication** - Currently disabled in Python version due to YouTube API changes. Will mirror this limitation.

3. **Rate Limiting** - YouTube aggressively rate limits. Proxy support is essential for production use.

---

## Success Criteria

- [ ] All tests pass (`bundle exec rspec`)
- [ ] Can fetch transcripts for public videos
- [ ] Language selection works correctly
- [ ] Translation feature works
- [ ] All formatters produce correct output
- [ ] Error handling matches expected behavior
- [ ] README examples work as documented