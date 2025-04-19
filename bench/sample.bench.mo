import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Local_log "../src";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Local_log");
    bench.description("Benchmarking Local_log");

    bench.rows(["test" ]);
    bench.cols(["10", "10000", "1000000"]);

    bench.runner(func(row, col) {
      let ?n = Nat.fromText(col);

      // Vector
      if (row == "test") {
        
        for (i in Iter.range(1, n)) {
          ignore Local_log.test();
        };
      }
    });

    bench;
  };
};