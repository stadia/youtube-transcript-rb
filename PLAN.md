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
├── api.rb               # ✅ Completed (Phase 3)
├── formatters.rb        # ✅ Completed (Phase 4)
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

## Phase 3: Main API ✅ COMPLETED

### Task 3.1: Create YouTubeTranscriptApi (`api.rb`) ✅

**Status:** Completed  
**Commit:** `290c9d2 Phase 3: Implement YouTubeTranscriptApi main entry point`

Main entry point class implemented:
- `YouTubeTranscriptApi.new(http_client:, proxy_config:)` - Constructor with optional config
- `fetch(video_id, languages:, preserve_formatting:)` - Fetch single transcript
- `list(video_id)` - List all available transcripts for a video
- `fetch_all(video_ids, ...)` - Batch fetch with error handling and yield support

Features:
- Default Faraday HTTP client with 30s timeout
- Configurable HTTP client for custom setups
- Proxy configuration support
- `continue_on_error` option for batch processing
- Block yielding for progress tracking

### Task 3.2: Update Main Module (`rb.rb`) ✅

**Status:** Completed

Convenience methods already existed and now work:
- `Youtube::Transcript::Rb.fetch(video_id, languages:, preserve_formatting:)`
- `Youtube::Transcript::Rb.list(video_id)`

### Phase 3 Test Results
- **33 new examples** for YouTubeTranscriptApi
- **252 total examples, 0 failures**
- Test file: `spec/api_spec.rb`

---

## Phase 4: Formatters ✅ COMPLETED

### Task 4.1: Create Formatter Classes (`formatters.rb`) ✅

**Status:** Completed  
**Commit:** `ec9c985 Phase 4: Implement Formatters for transcript output`

Formatter hierarchy implemented:
- `Formatter` - Abstract base class
- `JSONFormatter` - JSON output with configurable options
- `TextFormatter` - Plain text (text only, no timestamps)
- `PrettyPrintFormatter` - Ruby pretty-printed output
- `TextBasedFormatter` - Base for timestamp-based formatters
- `SRTFormatter` - SubRip format (`HH:MM:SS,mmm`)
- `WebVTTFormatter` - Web Video Text Tracks (`HH:MM:SS.mmm`)
- `FormatterLoader` - Utility to load formatters by name

Features:
- `format_transcript(transcript)` - Format single transcript
- `format_transcripts(transcripts)` - Format multiple transcripts
- Proper timestamp handling with hours/mins/secs/ms
- Overlapping timestamp correction
- SRT includes sequence numbers
- WebVTT includes WEBVTT header

### Phase 4 Test Results
- **53 new examples** for Formatters
- **305 total examples, 0 failures**
- Test file: `spec/formatters_spec.rb`

---

## Phase 5: Proxy Support (Optional) ⏳ (Optional)

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

## Phase 6: Testing ✅ COMPLETED

### Task 6.1: Unit Tests for Each Component ✅

**Status:** Completed (All phases)

Test files:
- `spec/errors_spec.rb` - 15+ error classes tested
- `spec/settings_spec.rb` - Constants and settings
- `spec/transcript_spec.rb` - Transcript data classes
- `spec/transcript_parser_spec.rb` - XML parsing
- `spec/transcript_list_spec.rb` - TranscriptList operations
- `spec/transcript_list_fetcher_spec.rb` - HTTP fetching with WebMock
- `spec/api_spec.rb` - YouTubeTranscriptApi main entry point
- `spec/formatters_spec.rb` - All formatter classes

### Task 6.2: Integration Tests ✅

**Status:** Completed  
**File:** `spec/integration_spec.rb`

Integration tests with real YouTube video IDs (skipped by default):
```ruby
# Run integration tests:
INTEGRATION=1 bundle exec rspec spec/integration_spec.rb
```

Test coverage:
- `YouTubeTranscriptApi#list` - Fetches real transcript list
- `YouTubeTranscriptApi#fetch` - Fetches real transcripts with language options
- `YouTubeTranscriptApi#fetch_all` - Batch fetching
- Convenience methods (`Youtube::Transcript::Rb.fetch`, `.list`)
- Transcript translation
- All formatters with real data (JSON, Text, SRT, WebVTT, PrettyPrint)
- Error handling (NoTranscriptFound, invalid video ID)
- FetchedTranscript interface (Enumerable, indexable, metadata)
- TranscriptList interface (Enumerable, find methods)
- Transcript object properties and methods

**Integration Test Results:** 31 examples, 0 failures, 2 pending (expected)

---

## Implementation Progress

### Completed Phases

| Phase | Status | Files | Tests |
|-------|--------|-------|-------|
| Phase 1: Core Infrastructure | ✅ Completed | `errors.rb`, `settings.rb`, `transcript.rb`, `transcript_parser.rb` | 149 examples |
| Phase 2: Transcript Fetching | ✅ Completed | `transcript_list.rb`, `transcript_list_fetcher.rb` | 70 examples |
| Phase 3: Main API | ✅ Completed | `api.rb` | 33 examples |
| Phase 4: Formatters | ✅ Completed | `formatters.rb` | 53 examples |
| Phase 6: Integration Tests | ✅ Completed | `integration_spec.rb` | 31 examples |

### Remaining Phases

| Phase | Status | Files | Estimated Effort |
|-------|--------|-------|------------------|
| Phase 5: Proxy Support | ❌ Optional | `proxies.rb` | 1.5 hours |

### Git Commits

| Commit | Description |
|--------|-------------|
| Phase 1 | Core infrastructure - errors, settings, transcript classes, parser |
| `ccae0eb` | Phase 2 - TranscriptList and TranscriptListFetcher |
| `290c9d2` | Phase 3 - YouTubeTranscriptApi main entry point |
| `ec9c985` | Phase 4 - Formatters for transcript output |
| Phase 6 | Integration tests with real YouTube videos |

### Current Test Summary

**Unit Tests:**
```
305 examples, 0 failures
```

**Integration Tests (run with INTEGRATION=1):**
```
31 examples, 0 failures, 2 pending
```

Test files:
- `spec/errors_spec.rb`
- `spec/settings_spec.rb`
- `spec/transcript_spec.rb`
- `spec/transcript_parser_spec.rb`
- `spec/transcript_list_spec.rb`
- `spec/transcript_list_fetcher_spec.rb`
- `spec/api_spec.rb`
- `spec/formatters_spec.rb`
- `spec/integration_spec.rb` (requires INTEGRATION=1)

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

- [x] All tests pass (`bundle exec rspec`) - **305 examples, 0 failures**
- [x] Can fetch transcripts for public videos (YouTubeTranscriptApi implemented)
- [x] Language selection works correctly (TranscriptList.find_transcript)
- [x] Translation feature works (Transcript.translate)
- [x] All formatters produce correct output (JSON, Text, SRT, WebVTT, PrettyPrint)
- [x] Error handling matches expected behavior (15+ error classes)
- [x] README examples work as documented (README updated)
- [x] Integration tests pass with real YouTube videos (**31 examples, 0 failures**)