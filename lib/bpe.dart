import 'package:bpe/tiktoken/tiktoken_tokenizer_gpt4o_o1.dart' as t1;
import 'package:characters/characters.dart';
import 'package:toxic/toxic.dart';

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
    int chunkSize = 16384,
    int overlapSize = 200,
  }) async* {
    StringBuffer buffer = StringBuffer();
    String leftover = '';

    await for (String chunk in source) {
      buffer.clear();
      buffer.write(leftover);
      buffer.write(chunk);

      String combinedText = buffer.toString();
      List<int> allTokens = encode(combinedText);
      int overlapStart =
          combinedText.length > overlapSize
              ? combinedText.length - overlapSize
              : 0;
      String overlapText = combinedText.substring(overlapStart);
      List<int> overlapTokens = encode(overlapText);
      int overlapTokenCount = overlapTokens.length;
      int finalTokenCount = allTokens.length - overlapTokenCount;

      if (finalTokenCount > 0) {
        for (int index = 0; index < finalTokenCount; index++) {
          yield allTokens[index];
        }
      }

      leftover = overlapText;
    }

    if (leftover.isNotEmpty) {
      List<int> leftoverTokens = encode(leftover);
      for (int token in leftoverTokens) {
        yield token;
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

const List<String> defaultChunkingSplitPriority = ["\n", ".", ",", " "];

extension XStreamStr on Stream<String> {
  Stream<String> cleanChunks({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = defaultChunkingSplitPriority,
  }) => accumulateClean(splitPriority: splitPriority)
      .accumulate(size: (size + grace) * 2)
      .chunk(size: size, grace: grace, splitPriority: splitPriority);

  Stream<String> accumulateClean({
    List<String> splitPriority = defaultChunkingSplitPriority,
  }) async* {
    List<String> pendingChunks = [];

    await for (String chunk in expand((i) => i.characters)) {
      pendingChunks =
          pendingChunks.isEmpty ? [chunk] : [pendingChunks[0] + chunk];

      int priorityIndex = 0;
      while (pendingChunks.length < 2 && priorityIndex < splitPriority.length) {
        pendingChunks =
            pendingChunks[0].chop(splitPriority[priorityIndex]).toList();
        priorityIndex++;
      }

      if (pendingChunks.length > 1) {
        yield pendingChunks.sublist(0, pendingChunks.length - 1).join();
        pendingChunks = pendingChunks.sublist(pendingChunks.length - 1);
      }
    }

    String remainingText = pendingChunks.join();
    if (remainingText.isNotEmpty) yield remainingText;
  }

  Stream<String> chunk({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = defaultChunkingSplitPriority,
  }) => asyncExpand(
    (i) => i.chunk(size: size, grace: grace, splitPriority: splitPriority),
  );

  Stream<String> accumulate({int size = 8192}) =>
      accumulateBy(size, (s) => s.length).map((i) => i.join());
}

extension XStringChunker on String {
  Stream<String> chunk({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = defaultChunkingSplitPriority,
  }) =>
      _chunkByPriority(size: size, grace: grace, splitPriority: splitPriority);

  Stream<String> accumulate({
    int size = 300,
    int grace = 300,
    List<String> splitPriority = defaultChunkingSplitPriority,
  }) =>
      _chunkByPriority(size: size, grace: grace, splitPriority: splitPriority);

  Stream<String> _chunkByPriority({
    required int size,
    required int grace,
    required List<String> splitPriority,
  }) async* {
    StringBuffer buffer = StringBuffer();

    for (int index = 0; index < length; index++) {
      String character = this[index];
      bool shouldCut = false;

      if (buffer.length >= size) {
        for (
          int priorityIndex = 0;
          priorityIndex < splitPriority.length;
          priorityIndex++
        ) {
          if (character == splitPriority[priorityIndex] &&
              buffer.length > size + (grace * priorityIndex)) {
            shouldCut = true;
            break;
          }
        }

        if (!shouldCut &&
            buffer.length > size + (grace * splitPriority.length)) {
          shouldCut = true;
        }

        if (shouldCut) {
          buffer.write(character);
          yield buffer.toString();
          buffer.clear();
          continue;
        }
      }

      buffer.write(character);
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

    for (int index = 0; index < parts.length; index++) {
      if (index < parts.length - 1) {
        yield "${parts[index]}$by";
      } else {
        yield parts[index];
      }
    }
  }
}
