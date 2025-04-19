import Time "mo:base/Time";
import Principal "mo:base/Principal";
import OVSFixed "mo:ovs-fixed";
import TimerToolLib "mo:timer-tool";
import VectorLib "mo:vector";

// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead

module {
  public let TimerTool = TimerToolLib;
  public let Vector = VectorLib;

  // LogLevel compatible with public service.mo
  public type LogLevel = {
    #Debug;
    #Info;
    #Warn;
    #Error;
    #Fatal;
  };

  public type LogEntry = {
    timestamp: Nat;
    message: Text;
    level: Nat;
    namespace: Text;
  };

  public type InitArgs = {
    min_level: ?LogLevel;         // minimum log level (optional)
    bufferSize: ?Nat;             // max buffer size
  };

  public type ICRC85Options = OVSFixed.ICRC85Environment;

  public type Environment = {
    tt: TimerToolLib.TimerTool;
    advanced : ?{
      icrc85 : ICRC85Options;
    };
    onEvict : ?([LogEntry] -> ()); // Optional handler for removed (evicted) records
  };

  // Stats exposes all non-recursive State fields for read-only inspection/debugging
  public type Stats = {
    tt: TimerToolLib.Stats;
    icrc85: {
      nextCycleActionId: ?Nat;
      lastActionReported: ?Nat;
      activeActions: Nat;
    };
    bufferSize: Nat;
    minLevel: ?LogLevel;
    log: [LogEntry];
  };

  ///MARK: State
  public type State = {
    icrc85: {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };
    var bufferSize: Nat;         // log buffer maximum size; controls rollover
    var entries: Vector.Vector<LogEntry>;     // deprecated, kept for stable compatibility
    var minLevel: ?LogLevel;     // optional minimum log level for this logger
    var maxMessageSize: Nat; // maximum message size 
    var printLinesToConsole: Bool; 
  };
};