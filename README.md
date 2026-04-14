# BPE

`bpe` provides fast BPE tokenizers for `cl100k_base` and `o200k_base`, along with chunking helpers for working with large strings and `Stream<String>` inputs.

It is useful when you want to:

- encode text into token IDs
- decode token IDs back into text
- estimate token usage for large documents without processing the whole document as one giant string
- split text into cleaner chunks that prefer natural boundaries like newlines, spaces, and periods

## Available Tokenizers

- `CL100kBaseBPETokenizer()`
- `O200kBaseBPETokenizer()`

## Basic Usage

```dart
import 'package:bpe/bpe.dart';

void main() {
  BPETokenizer tokenizer = O200kBaseBPETokenizer();
  String text = 'Hello from bpe.';

  List<int> tokens = tokenizer.encode(text);
  String decoded = tokenizer.decode(tokens);

  print(tokens);
  print(decoded);
}
```

## Estimating Tokens For Large Text

`estimateTokens()` is the easiest way to get a stream-based estimate for a large string.

Instead of treating the whole input as a single block, it chunks the text first and then estimates from those chunks.

```dart
import 'package:bpe/bpe.dart';

Future<void> main() async {
  BPETokenizer tokenizer = CL100kBaseBPETokenizer();
  String document = 'Very large text here...' * 5000;

  int estimatedTokens = await tokenizer.estimateTokens(document);

  print('Estimated tokens: $estimatedTokens');
}
```

This is a good fit for:

- prompt budgeting
- long articles
- books
- logs
- scraped content
- ingestion pipelines

## Estimating Tokens From A Stream

If your text already arrives in pieces, use `estimateTokensStream()`.

```dart
import 'package:bpe/bpe.dart';

Future<void> main() async {
  BPETokenizer tokenizer = O200kBaseBPETokenizer();
  Stream<String> source = Stream<String>.fromIterable([
    'Page one content.\n',
    'Page two content.\n',
    'Page three content.\n',
  ]);

  int estimatedTokens = await tokenizer.estimateTokensStream(source);

  print('Estimated tokens: $estimatedTokens');
}
```

This helps when reading from:

- files
- sockets
- HTTP streams
- paginated fetches
- chunked parsing pipelines

## Chunking Helpers

The package also exposes chunking extensions on both `String` and `Stream<String>`.

These helpers try to avoid ugly hard splits by preferring boundaries in this order by default:

1. newline
2. space
3. period

### `String.chunk()`

Use this when you already have a full string and want a `Stream<String>` of cleaner chunks.

```dart
import 'package:bpe/bpe.dart';

Future<void> main() async {
  String text = '''
This is a long paragraph.
It has multiple lines and sentences.
Chunking tries to cut at natural boundaries when it can.
''';

  await for (String chunk in text.chunk(size: 40, grace: 20)) {
    print('---');
    print(chunk);
  }
}
```

### `Stream<String>.cleanChunks()`

Use this when your incoming stream is already fragmented in awkward places and you want to normalize it into cleaner output chunks.

```dart
import 'package:bpe/bpe.dart';

Future<void> main() async {
  Stream<String> messyStream = Stream<String>.fromIterable([
    'Hello wo',
    'rld. This is a str',
    'eam that was split badly.\nNext li',
    'ne starts here.',
  ]);

  await for (String chunk in messyStream.cleanChunks(size: 30, grace: 10)) {
    print('---');
    print(chunk);
  }
}
```

This is especially useful when upstream data is split arbitrarily and you want chunk boundaries that are more readable and safer for token estimation.

## Chunking Options

The chunking APIs share the same knobs:

- `size`: preferred chunk size
- `grace`: extra room allowed while waiting for a better split point
- `splitPriority`: preferred split markers in order

Example:

```dart
import 'package:bpe/bpe.dart';

Future<void> main() async {
  String text = 'A very long string...' * 200;

  await for (String chunk in text.chunk(
    size: 1200,
    grace: 300,
    splitPriority: ['\n', ' ', '.', ','],
  )) {
    print(chunk.length);
  }
}
```

## When To Use Which API

- Use `encode()` when you need the actual token IDs.
- Use `decode()` when you need the text back from token IDs.
- Use `estimateTokens()` when you already have one large string.
- Use `estimateTokensStream()` when text arrives over time as a stream.
- Use `String.chunk()` when you want clean chunk boundaries from one string.
- Use `Stream<String>.cleanChunks()` when you want to repair or normalize a fragmented text stream before further processing.
