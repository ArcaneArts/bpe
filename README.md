# BPE

```dart
import 'package:bpe/bpe.dart';

void main() {
  String something = "Some chars";
  
  BPETokenizer tokenizer = O200kBaseBPETokenizer();
  List<String> tokens = tokenizer.encode(something);
  String decoded = tokenizer.decode(tokens);
  
  // Estimate tokens without blowing up the heap by streaming in chunks
  String example =
      """Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.""" *
          100;
  
  print("CHAR is ${example.length}"); // 57400
  print("Real is ${tokenizer.encode(example).length}"); // 11400
  
  // Estimate the tokens efficiently ~99.57% accurate. Multiply count by 0.06 to ensure 
  // the estimate doesnt undershoot the actual token count (ceil)
  print("ESTI is ${await tokenizer.estimateTokens(example)}"); // 11449 (streams in chunks)
  
  // You can also feed real streams of strings to estimate tokens
  // It will only have a buffer of ~1024 to 2048 characters
  Future<int> estimateTokensStream(Stream.fromIterable([example]));
}
```