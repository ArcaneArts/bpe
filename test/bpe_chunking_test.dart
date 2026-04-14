import 'package:bpe/bpe.dart';
import 'package:test/test.dart';

void main() {
  group('XStringChunker', () {
    test('chop returns original string when separator is missing', () {
      List<String> parts = 'alphabet'.chop('|').toList();

      expect(parts, ['alphabet']);
    });

    test('chop keeps separator on each non-terminal segment', () {
      List<String> parts = 'one,two,three'.chop(',').toList();

      expect(parts, ['one,', 'two,', 'three']);
    });

    test(
      'chunk returns one chunk when text is below the preferred size',
      () async {
        List<String> chunks = await 'short text'.chunk(size: 50).toList();

        expect(chunks, ['short text']);
      },
    );

    test(
      'chunk prefers configured delimiters once the preferred size is exceeded',
      () async {
        List<String> chunks =
            await 'alpha beta gamma'
                .chunk(size: 5, grace: 10, splitPriority: [' '])
                .toList();

        expect(chunks, ['alpha beta ', 'gamma']);
      },
    );
  });

  group('XStreamStr', () {
    test('chunk applies string chunking rules to each stream item', () async {
      Stream<String> source = Stream<String>.fromIterable(['alpha beta gamma']);
      List<String> chunks =
          await source.chunk(size: 5, grace: 10, splitPriority: [' ']).toList();

      expect(chunks, ['alpha beta ', 'gamma']);
    });

    test(
      'accumulate joins adjacent stream items until the size limit would be exceeded',
      () async {
        Stream<String> source = Stream<String>.fromIterable([
          'ab',
          'cd',
          'efg',
          'h',
        ]);
        List<String> chunks = await source.accumulate(size: 4).toList();

        expect(chunks, ['abcd', 'efgh']);
      },
    );

    test('accumulate returns no chunks for an empty stream', () async {
      Stream<String> source = Stream<String>.empty();
      List<String> chunks = await source.accumulate(size: 4).toList();

      expect(chunks, isEmpty);
    });

    test(
      'accumulateClean repairs fragmented input and emits on delimiter boundaries',
      () async {
        Stream<String> source = Stream<String>.fromIterable([
          'Hello',
          ' world.',
          ' Next',
          ' sentence.',
        ]);
        List<String> chunks =
            await source.accumulateClean(splitPriority: ['.']).toList();

        expect(chunks, ['Hello world.', ' Next sentence.']);
      },
    );

    test(
      'cleanChunks normalizes fragmented text into readable output chunks',
      () async {
        Stream<String> source = Stream<String>.fromIterable([
          'Hello wo',
          'rld.',
          ' Next sen',
          'tence.',
        ]);
        List<String> chunks =
            await source
                .cleanChunks(size: 50, grace: 0, splitPriority: ['.'])
                .toList();

        expect(chunks, ['Hello world. Next sentence.']);
      },
    );
  });
}
