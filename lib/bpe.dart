library bpe;

import 'package:bpe/tiktoken/tiktoken_tokenizer_gpt4o_o1.dart' as t1;
import 'package:characters/characters.dart';

void main() async {
  String example =
      """Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.""" *
      100;

  print("CHAR is ${example.length}");
  print("Real is ${CL100kBaseBPETokenizer().encode(example).length}");
  print("ESTI is ${await CL100kBaseBPETokenizer().estimateTokens(example)}");
}

abstract class BPETokenizer {
  const BPETokenizer();

  List<int> encode(String text);

  String decode(List<int> tokens);

  Future<int> estimateTokensStream(Stream<String> text) => text
      .cleanChunks(size: 1024, grace: 500)
      .map((i) => encode(i).length)
      .fold(0, (a, b) => a + b);

  Future<int> estimateTokens(String text) =>
      estimateTokensStream(text.chunk(size: 1024, grace: 500));

  Stream<int> encodeStreamTest(
    Stream<String> source, {
    int chunkSize = 16384, // how many chars we read each time (approx)
    int overlapSize = 200, // how many chars to keep from the end of combined
  }) async* {
    final buffer = StringBuffer(); // accumulates partial chunk data
    String leftover = ''; // leftover from last iteration

    await for (String chunk in source) {
      // Add new chunk to leftover
      buffer.clear();
      buffer.write(leftover);
      buffer.write(chunk);

      final combinedText = buffer.toString();

      // Tokenize the entire combined text
      final allTokens = encode(combinedText);

      // Decide how many raw characters from the tail of combinedText
      // we want to keep as "overlap" for the next chunk
      final overlapStart =
          (combinedText.length > overlapSize)
              ? (combinedText.length - overlapSize)
              : 0;
      final overlapText = combinedText.substring(overlapStart);

      // We want to figure out how many tokens that substring (overlapText)
      // corresponds to, so we re-tokenize just the overlapText:
      final overlapTokens = encode(overlapText);
      final overlapTokenCount = overlapTokens.length;

      // So everything in allTokens before that overlap region is "final"
      final finalTokenCount = allTokens.length - overlapTokenCount;
      if (finalTokenCount > 0) {
        // Yield out the "final" tokens
        for (int i = 0; i < finalTokenCount; i++) {
          yield allTokens[i];
        }
      }

      // Save leftover = overlapText for next iteration
      leftover = overlapText;
    }

    // After the stream completes, we still may have leftover unfinalized text.
    // We tokenize leftover alone and yield those tokens.
    if (leftover.isNotEmpty) {
      final leftoverTokens = encode(leftover);
      for (final t in leftoverTokens) {
        yield t;
      }
    }
  }
}

class CL100kBaseBPETokenizer extends BPETokenizer {
  const CL100kBaseBPETokenizer();

  @override
  String decode(List<int> tokens) => t1.Tiktoken.getEncoder(
    t1.TiktokenEncodingType.cl100k_base,
  ).decode(tokens);

  @override
  List<int> encode(String text) =>
      t1.Tiktoken.getEncoder(t1.TiktokenEncodingType.cl100k_base).encode(text);
}

class O200kBaseBPETokenizer extends BPETokenizer {
  const O200kBaseBPETokenizer();

  @override
  String decode(List<int> tokens) =>
      t1.Tiktoken.getEncoder(t1.TiktokenEncodingType.o200k_base).decode(tokens);

  @override
  List<int> encode(String text) =>
      t1.Tiktoken.getEncoder(t1.TiktokenEncodingType.o200k_base).encode(text);
}

extension XStreamStr on Stream<String> {
  Stream<String> cleanChunks({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = const ["\n", " ", "."],
  }) => accumulateClean(splitPriority: splitPriority)
      .accumulate(size: (size + grace) * 2)
      .chunk(size: size, grace: grace, splitPriority: splitPriority);

  Stream<String> accumulateClean({
    List<String> splitPriority = const ["\n", " ", "."],
  }) async* {
    List<String> c = [];
    await for (String chunk in expand((i) => i.characters)) {
      c = c.isEmpty ? [chunk] : [c[0] + chunk];

      int a = 0;
      while (c.length < 2 && a < splitPriority.length) {
        c = c[0].chop(splitPriority[a]).toList();
        a++;
      }

      if (c.length > 1) {
        yield c.sublist(0, c.length - 1).join();
        c = c.sublist(c.length - 1);
      }
    }

    if (c.isNotEmpty) {
      if (c.join().isNotEmpty) {
        yield c.join();
      }
    }
  }

  Stream<String> chunk({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = const ["\n", " ", "."],
  }) => asyncExpand(
    (i) => i.chunk(size: size, grace: grace, splitPriority: splitPriority),
  );

  Stream<String> accumulate({int size = 8192}) =>
      accumulateBy(size, (s) => s.length).map((i) => i.join());
}

extension XStreamAcc<T> on Stream<T> {
  Stream<List<T>> accumulateBy(
    int limit,
    int Function(T) weigher, {
    int? maxAmount,
  }) async* {
    List<T> buffer = [];
    int size = 0;

    await for (T chunk in this) {
      if (maxAmount != null && buffer.length >= maxAmount) {
        yield buffer;
        buffer = [];
        size = 0;
      }

      int weight = weigher(chunk);

      if (size + weight > limit) {
        if (buffer.isNotEmpty) {
          yield buffer;
          buffer = [];
          size = 0;
        } else {
          yield [chunk];
          buffer = [];
          size = 0;
        }
      }

      buffer.add(chunk);
      size += weight;
    }

    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}

extension XStringChunker on String {
  Stream<String> chunk({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = const ["\n", " ", "."],
  }) async* {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      String char = this[i];
      bool cut = false;

      if (buffer.length >= size) {
        for (int j = 0; j < splitPriority.length; j++) {
          if (char == splitPriority[j] && buffer.length > size + (grace * j)) {
            cut = true;
            break;
          }
        }

        if (!cut && buffer.length > size + (grace * splitPriority.length)) {
          cut = true;
        }

        if (cut) {
          buffer.write(char);
          yield buffer.toString();
          buffer.clear();
          continue;
        }
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      yield buffer.toString();
    }
  }

  Stream<String> accumulate({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = const ["\n", " ", "."],
  }) async* {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      String char = this[i];
      bool cut = false;

      if (buffer.length >= size) {
        for (int j = 0; j < splitPriority.length; j++) {
          if (char == splitPriority[j] && buffer.length > size + (grace * j)) {
            cut = true;
            break;
          }
        }

        if (!cut && buffer.length > size + (grace * splitPriority.length)) {
          cut = true;
        }

        if (cut) {
          buffer.write(char);
          yield buffer.toString();
          buffer.clear();
          continue;
        }
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      yield buffer.toString();
    }
  }

  Iterable<String> chop(String by) sync* {
    if (!contains(by)) {
      yield this;
      return;
    }

    List<String> parts = split(by);

    for (int i = 0; i < parts.length; i++) {
      if (i < parts.length - 1) {
        yield "${parts[i]}$by";
      } else {
        yield parts[i];
      }
    }
  }
}
