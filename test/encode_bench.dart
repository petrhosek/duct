import 'package:benchmark_harness/benchmark_harness.dart';

class EncodeBenchmark extends BenchmarkBase {
  const EncodeBenchmark() : super("Encode");

  static void main() {
    new EncodeBenchmark().report();
  }

  // The benchmark code.
  void run() {
  }

  // Not measured setup code executed prior to the benchmark runs.
  void setup() { }

  // Not measures teardown code executed after the benchark runs.
  void teardown() { }
}

main() {
  EncodeBenchmark.main();
}