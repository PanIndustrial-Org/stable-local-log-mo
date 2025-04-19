import Time "mo:base/Time";
import Principal "mo:base/Principal";
import OVSFixed "mo:ovs-fixed";
import TimerToolLib "mo:timer-tool";

// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead


module {

  public let TimerTool = TimerToolLib;


  public type InitArgs = {};

  public type ICRC85Options = OVSFixed.ICRC85Environment;

  public type Environment = {
    tt: TimerToolLib.TimerTool;
    advanced : ?{
      icrc85 : ICRC85Options;
    };
  };

  public type Stats = {
    tt: TimerToolLib.Stats;
    icrc85: {
      nextCycleActionId: ?Nat;
      lastActionReported: ?Nat;
      activeActions: Nat;
    };
    log: [Text];
  };

  ///MARK: State
  public type State = {
    icrc85: {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };
  };
};