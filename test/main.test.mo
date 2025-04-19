import {test} "mo:test/async";
import Local_log "../src/main";
import ExperimentalCycles "mo:base/ExperimentalCycles";

actor {
  

  public func runTests() : async () {


    // add cycles to deploy your canister
    ExperimentalCycles.add<system>(1_000_000_000_000);

    // deploy your canister
    let myCanister = await Local_log.Local_logCanister(null);

    await test("test name", func() : async () {
      let res = await myCanister.hello();
      assert res == "world!";
    });
  };
};