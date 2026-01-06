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
├── transcript_parser.rb # ✅ Completed (Phase 1)
├── transcript_list.rb   # ✅ Completed (Phase 2)
├── transcript_list_fetcher.rb  # ✅ Completed (Phase 2)
├── api.rb               # ❌ To be created (Phase 3)
├── formatters.rb        # ❌ To be created (Phase 4)
└── proxies.rb           # ❌ To be created (optional, Phase 5)
```

---

## Phase 1: Core Infrastructure ✅ COMPLETED

### Task 1.1: Create Error Classes (`errors.rb`) ✅

**Status:** Completed  
**Commit:** Phase 1 commit

Created comprehensive exception hierarchy (15+ classes) mirroring Python's `_errors.py`:
- `Error` - Base error class
- `CouldNotRetrieveTranscript` - Base class for transcript retrieval errors
- `VideoUnavailable`, `TranscriptsDisabled`, `NoTranscriptFound`, etc.
- Each error class includes appropriate attributes and formatted error messages

### Task 1.2: Create Settings/Constants (`settings.rb`) ✅

**Status:** Completed

Constants defined:
- `WATCH_URL` - YouTube watch page URL template
- `INNERTUBE_API_URL` - Innertube API endpoint template
- `INNERTUBE_CONTEXT` - Android client context for API requests

### Task 1.3: Create Transcript Data Classes (`transcript.rb`) ✅

**Status:** Completed

Classes implemented:
- `TranslationLanguage` - Language code and name pair
- `TranscriptSnippet` - Individual transcript segment (text, start, duration)
- `FetchedTranscript` - Collection of snippets with Enumerable support
- `Transcript` - Metadata with `fetch` and `translate` methods

### Task 1.4: Create TranscriptParser (`transcript_parser.rb`) ✅

**Status:** Completed

Features:
- XML parsing with Nokogiri
- HTML entity unescaping with CGI
- `preserve_formatting` option
- Formatting tag handling (strong, em, b, i, etc.)

### Phase 1 Test Results
- **149 examples, 0 failures**
- Test files: `errors_spec.rb`, `transcript_spec.rb`, `transcript_parser_spec.rb`, `settings_spec.rb`

---

## Phase 2: Transcript Fetching ✅ COMPLETED

### Task 2.1: Create TranscriptListFetcher (`transcript_list_fetcher.rb`) ✅

**Status:** Completed  
**Commit:** `ccae0eb Phase 2: Implement TranscriptList and TranscriptListFetcher`

This is the most complex component. Implemented features:
1. Fetch video HTML page with `Accept-Language: en-US` header
2. Extract `INNERTUBE_API_KEY` from HTML using regex
3. Make POST request to Innertube API with Android client context
4. Parse captions JSON from response
5. Handle consent cookies for EU/GDPR compliance
6. Handle various error conditions

Key methods implemented:
- `fetch(video_id)` → `TranscriptList`
- `fetch_video_html(video_id)` - Fetches and unescapes HTML
- `extract_innertube_api_key(html, video_id)` - Regex extraction
- `fetch_innertube_data(video_id, api_key)` - POST to Innertube API
- `extract_captions_json(innertube_data, video_id)` - JSON extraction
- `assert_playability(status_data, video_id)` - Playability validation

Additional modules:
- `PlayabilityStatus` - OK, ERROR, LOGIN_REQUIRED constants
- `PlayabilityFailedReason` - BOT_DETECTED, AGE_RESTRICTED, VIDEO_UNAVAILABLE

Error handling:
- HTTP 429 → `IpBlocked`
- CAPTCHA detected → `IpBlocked`
- Bot detection → `RequestBlocked`
- Age restriction → `AgeRestricted`
- Video unavailable → `VideoUnavailable` or `InvalidVideoId`
- No captions → `TranscriptsDisabled`
- Consent issues → `FailedToCreateConsentCookie`

Retry support with proxy configuration.

### Task 2.2: Create TranscriptList (`transcript_list.rb`) ✅

**Status:** Completed

Factory and container for transcripts:
- `TranscriptList.build(http_client:, video_id:, captions_json:)` - Factory method
- Separates manually created and generated transcripts
- `find_transcript(language_codes)` - Finds by priority, prefers manual
- `find_manually_created_transcript(language_codes)`
- `find_generated_transcript(language_codes)`
- `Enumerable` included for iteration
- `to_s` for human-readable output

### Phase 2 Test Results
- **70 new examples** (38 for TranscriptList, 32 for TranscriptListFetcher)
- **219 total examples, 0 failures**
- Test files: `transcript_list_spec.rb`, `transcript_list_fetcher_spec.rb`
- Comprehensive HTTP mocking with WebMock

---

## Phase 3: Main API ⏳ NEXT

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

## Implementation Progress

### Completed Phases

| Phase | Status | Files | Tests |
|-------|--------|-------|-------|
| Phase 1: Core Infrastructure | ✅ Completed | `errors.rb`, `settings.rb`, `transcript.rb`, `transcript_parser.rb` | 149 examples |
| Phase 2: Transcript Fetching | ✅ Completed | `transcript_list.rb`, `transcript_list_fetcher.rb` | 70 examples |

### Remaining Phases

| Phase | Status | Files | Estimated Effort |
|-------|--------|-------|------------------|
| Phase 3: Main API | ⏳ Next | `api.rb`, update `rb.rb` | 1.5 hours |
| Phase 4: Formatters | ❌ Pending | `formatters.rb` | 2 hours |
| Phase 5: Proxy Support | ❌ Optional | `proxies.rb` | 1.5 hours |
| Phase 6: Integration Tests | ❌ Pending | Integration spec files | 2 hours |

### Git Commits

| Commit | Description |
|--------|-------------|
| Phase 1 | Core infrastructure - errors, settings, transcript classes, parser |
| `ccae0eb` | Phase 2 - TranscriptList and TranscriptListFetcher |

### Current Test Summary

```
219 examples, 0 failures
```

Test files:
- `spec/errors_spec.rb`
- `spec/settings_spec.rb`
- `spec/transcript_spec.rb`
- `spec/transcript_parser_spec.rb`
- `spec/transcript_list_spec.rb`
- `spec/transcript_list_fetcher_spec.rb`

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

- [x] All tests pass (`bundle exec rspec`) - **219 examples, 0 failures**
- [ ] Can fetch transcripts for public videos (requires Phase 3)
- [x] Language selection works correctly (TranscriptList.find_transcript)
- [x] Translation feature works (Transcript.translate)
- [ ] All formatters produce correct output (Phase 4)
- [x] Error handling matches expected behavior (15+ error classes)
- [ ] README examples work as documented (requires Phase 3)