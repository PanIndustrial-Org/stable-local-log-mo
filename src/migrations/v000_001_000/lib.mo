import MigrationTypes "../types";
import Time "mo:base/Time";
import v0_1_0 "types";
import D "mo:base/Debug";


module {

  let Vector = v0_1_0.Vector;


  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal, canister: Principal): MigrationTypes.State {
    // Use InitArgs to configure the initial state if provided (new installs or upgrades)
    let (minLevel, bufferSize) = switch(args) {
      case (?a) { ( a.min_level, a.bufferSize) };
      case (null) { (null, null) };
    };

    let state : v0_1_0.State = {
      icrc85 = {
        var nextCycleActionId: ?Nat = null; // Initialize to null or a specific value if needed
        var lastActionReported: ?Nat = null; // Initialize to null or a specific value if needed
        var activeActions: Nat = 0; // Initialize to 0 or a specific value if needed
      };
      var bufferSize = switch(bufferSize) { case(?sz) sz; case(null) 5000; };
      var entries = Vector.new<v0_1_0.LogEntry>();
      var minLevel = minLevel;
      var maxMessageSize = 10000;
      var printLinesToConsole = true;
    };

    return #v0_1_0(#data(state));
  };
};