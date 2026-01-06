# YouTube Transcript Ruby - Project Overview

## Purpose
This gem is a Ruby port of the Python library [youtube-transcript-api](https://github.com/jdepoix/youtube-transcript-api).
It retrieves transcripts/subtitles from YouTube videos without requiring an API key or headless browser.

## Python Library Features to Port
Based on the original Python library:
- Fetch transcripts for YouTube videos
- Support for automatically generated and manually created captions
- Language preference selection
- Translation support for translatable transcripts
- Multiple output formatters (JSON, WebVTT, SRT, plain text, PrettyPrint)
- HTML formatting preservation option
- Proxy support (Webshare, Generic HTTP/HTTPS/SOCKS)
- Error handling for various YouTube states

## Current Implementation Status
The gem has a basic skeleton but most implementation files are missing:
- ✅ `lib/youtube/transcript/rb.rb` - Main entry point with convenience methods
- ✅ `lib/youtube/transcript/rb/version.rb` - Version file (0.1.0)
- ❌ `lib/youtube/transcript/rb/errors.rb` - Not created yet
- ❌ `lib/youtube/transcript/rb/transcript.rb` - Not created yet
- ❌ `lib/youtube/transcript/rb/transcript_list.rb` - Not created yet
- ❌ `lib/youtube/transcript/rb/transcript_list_fetcher.rb` - Not created yet
- ❌ `lib/youtube/transcript/rb/api.rb` - Not created yet
- ❌ `lib/youtube/transcript/rb/formatters.rb` - Not created yet

## Key Classes Expected
- `YouTubeTranscriptApi` - Main API class with `fetch` and `list` methods
- `FetchedTranscript` - Represents fetched transcript data with snippets
- `TranscriptSnippet` / `FetchedTranscriptSnippet` - Individual transcript segments
- `TranscriptList` - List of available transcripts for a video
- `Transcript` - Metadata about a transcript (language, is_generated, etc.)
- Formatters: `TextFormatter`, `JSONFormatter`, `WebVTTFormatter`, `SRTFormatter`, `PrettyPrintFormatter`

## Module Namespace
```ruby
Youtube::Transcript::Rb
```
