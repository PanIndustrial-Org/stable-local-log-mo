import {test} "mo:test/async";
import Local_log "../src/main";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import LocalLogLib "../src/lib";
import D "mo:base/Debug";

actor {
  

  public func runTests() : async () {
    // add cycles to deploy your canister
    ExperimentalCycles.add<system>(1_000_000_000_000);
    // deploy your canister
    let canister = await Local_log.Local_logCanister(null);

    // hello world check
    await test("hello world", func() : async () {
      let res = await canister.hello();
      assert res == "world!";
    });

    // log_add + log_query basic
    await test("add a log, query, check contents", func() : async () {
      await canister.log_add("entry1", #Info, "default");
      let logs = await canister.log_query({namespaces = null; level = null; take = ?10; prev = null});
      assert logs.size() == 1;
      assert logs[0].message == "entry1" and logs[0].level == LocalLogLib.levelToNat(#Info) and logs[0].namespace == "default";
    });

    // log level filtering
    await test("log_query filters by log level", func() : async () {
      await canister.log_add("entry2", #Debug, "default");
      D.print("log level filtering");
      let logs = await canister.log_query({namespaces = null; level = ?#Debug; take = null; prev = null});
      D.print("logs: " # debug_show(logs));
      let found = logs.size() >= 1;
      assert found;
      assert logs[1].level == LocalLogLib.levelToNat(#Debug);
    });

    // namespace filtering
    await test("log_query filters by namespace", func() : async () {
      await canister.log_add("entry3", #Warn, "myspace");
      let logs = await canister.log_query({namespaces = ?["myspace"]; level = null; take = null; prev = null});
      D.print("logs result" # debug_show(logs) );
      assert logs.size() >= 1;
      assert logs[0].namespace == "myspace";
    });

    // clear only namespace logs
    await test("log_clear removes only namespace logs", func() : async () {
      let before = await canister.log_size(null, null);
      let cleared = await canister.log_clear();
      let after = await canister.log_size(null, null);
      assert cleared > 0;
      assert after < before;
      let logs = await canister.log_query({namespaces = ?["myspace"]; level = null; take = null; prev = null});
      assert logs.size() == 0;
    });

    // log buffer size operations
    await test("log_set/get_buffer_size", func() : async () {
      let orig = await canister.log_get_buffer_size();
      let set = await canister.log_set_buffer_size(42);
      assert set == 42;
      let got = await canister.log_get_buffer_size();
      assert got == 42;
      // Restore buffer size
      ignore await canister.log_set_buffer_size(orig);
    });

    // Export logs
    await test("log_export returns counts and entries", func() : async () {
      let exp = await canister.log_export({namespaces = null; level = null; take = ?999; prev = null});
      assert exp.exportedCount == exp.exported.size();
    });
  };
};