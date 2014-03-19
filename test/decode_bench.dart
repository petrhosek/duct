import 'package:benchmark_harness/benchmark_harness.dart';

class DecodeBenchmark extends BenchmarkBase {
  const DecodeBenchmark() : super("Decode");

  static void main() {
    new DecodeBenchmark().report();
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
  DecodeBenchmark.main();
}