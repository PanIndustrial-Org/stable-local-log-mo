import MigrationTypes "migrations/types";
import MigrationLib "migrations";
import ClassPlusLib "mo:class-plus";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Service "service";
import D "mo:base/Debug";
import Star "mo:star/star";
import ovsfixed "mo:ovs-fixed";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Error "mo:base/Error";
import Map "mo:map/Map";
import Vector "mo:vector";
import Text "mo:base/Text";

module {

  public let Migration = MigrationLib;
  public let TT = MigrationLib.TimerTool;
  public type State = MigrationTypes.State;
  public type CurrentState = MigrationTypes.Current.State;
  public type Environment = MigrationTypes.Current.Environment;
  public type Stats = MigrationTypes.Current.Stats;
  public type InitArgs = MigrationTypes.Current.InitArgs;

  public let init = Migration.migrate;

  public func initialState() : State { #v0_0_0(#data) };
  public let currentStateVersion = #v0_1_0(#id);

  public let ICRC85_Timer_Namespace = "icrc85:ovs:shareaction:local_log";
  public let ICRC85_Payment_Namespace = "com.panindustrial.libraries.local_log";

  public func test() : Nat {
    1;
  };

  public func levelToNat(level: MigrationTypes.Current.LogLevel): Nat {
    switch (level) {
      case (#Debug) 0;
      case (#Info) 1;
      case (#Warn) 2;
      case (#Error) 3;
      case (#Fatal) 4;
    };
  };

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(Local_log -> async*());
    onStorageChange : ((State) ->())
  }) : () -> Local_log {

    let instance = ClassPlusLib.ClassPlus<system,
      Local_log,
      State,
      InitArgs,
      Environment>({config with constructor = Local_log}).get;

    ovsfixed.initialize_cycleShare<system>({
      namespace = ICRC85_Timer_Namespace;
      icrc_85_state = instance().getState().icrc85;
      wait = null;
      registerExecutionListenerAsync = instance().environment.tt.registerExecutionListenerAsync;
      setActionSync = instance().environment.tt.setActionSync;  
      existingIndex = instance().environment.tt.getState().actionIdIndex;
      handler = instance().handleIcrc85Action;
    });
    
    instance;
    
  };

  /// Main logging class used internally and by canisters/classes as a module
  public class Local_log(
    stored: ?State,
    caller: Principal,
    canister: Principal,
    args: ?InitArgs,
    environment_passed: ?Environment,
    storageChanged: (State) -> ()
  ) {

    public let debug_channel = { var announce = true };
    public let environment = switch (environment_passed) {
      case (?val) val;
      case (null) { D.trap("Environment is required") };
    };

    // Keep other state as before
    var state : CurrentState = switch (stored) {
      case (null) {
        let #v0_1_0(#data(foundState)) = init(initialState(), currentStateVersion, args, caller, canister);
        foundState;
      };
      case (?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, args, caller, canister);
        foundState;
      };
    };
    storageChanged(#v0_1_0(#data(state)));


    // Core log functions
    private func nowNat(): Nat = Int.abs(Time.now());

    /// Internal utility: Test if log level passes configured minimum level
    private func passesLevel(level: MigrationTypes.Current.LogLevel): Bool {
      switch (state.minLevel) {
        case (null) true;
        case (?#Debug) true;
        case (?#Info) {
          switch(level) {
            case (#Debug) false;
            case (_) true;
          };
        
        };
        case (?#Warn) {
          switch(level) {
            case (#Debug) false;
            case (#Info) false;
            case (_) true;
          };
        };
        case (?#Error) {
          switch(level) {
            case (#Debug) false;
            case (#Info) false;
            case (#Warn) false;
            case (_) true;
          };
        };
        case (?#Fatal) {
          switch(level) {
            case (#Fatal) true;
            case (_) false;
          };
        };
      };
    };

    /// Internal: Check if any namespace matches
    private func inNamespaces(namespaces: [Text], search: Text): Bool {
      for (ns in namespaces.vals()) if (ns == search) return true;
      false
    };

    //add public shortcut to log for each level
    public func log_debug(message: Text, namespace: Text) : () {
      log_add(message, #Debug, namespace);
    };
    public func log_info(message: Text, namespace: Text) : () {
      log_add(message, #Info, namespace);
    };
    public func log_warn(message: Text, namespace: Text) : () {
      log_add(message, #Warn, namespace);
    };
    public func log_error(message: Text, namespace: Text) : () {
      log_add(message, #Error, namespace);
    };
    public func log_fatal(message: Text, namespace: Text) : () {
      log_add(message, #Fatal, namespace);
    };

    /// Add one log entry to buffer for each namespace
    public func log_add(message: Text, level: MigrationTypes.Current.LogLevel, namespace: Text) : () {
     
      if (not passesLevel(level)) return;
      let finalText = if(message.size() > state.maxMessageSize) {
        var marker : Nat = 0;
        let modified = Text.translate(message, func(c){
          if (marker >= state.maxMessageSize){ return ""};
          marker += 1;
          Text.fromChar(c);
        });
        modified # "...";
      } else {
        message;
      };
      
      state.icrc85.activeActions += 1;
      
      let entry : MigrationTypes.Current.LogEntry = {
        timestamp = nowNat();
        message = finalText;
        level = levelToNat(level);
        namespace = namespace;
      };
      // Add to Vector, remove oldest if buffer at limit
      if (Vector.size(state.entries) >= state.bufferSize) {
        ignore log_clear();
      };
      Vector.add(state.entries, entry);
      if(state.printLinesToConsole){
        debug D.print(debug_show(entry));
      };
    };

    

    /// Query log entries with optional filtering
    public func log_query(q: Service.LogQuery): [MigrationTypes.Current.LogEntry] {
      D.print("log_query: " # debug_show(q));
      let nsFilter = q.namespaces;
      let lvlFilter = q.level;
      let buf = Buffer.Buffer<MigrationTypes.Current.LogEntry>(1);
      var skip : Nat = switch (q.prev) { case (null) 0; case (?n) n };
      var added = 0;
      let max = switch (q.take) { case (null) 1000; case (?m) m };
      let size = Vector.size(state.entries);
      label filter for (i in Iter.range(0, size - 1)) {
        if (i < skip) continue filter;
        let e = Vector.get(state.entries, i);
        switch(nsFilter) {
          case(null) {};
          case(?arr) { if (not inNamespaces(arr, e.namespace)) continue filter; }
        };
        switch(lvlFilter) {
          case(null) {};
          case(?lev) { 
            let test = levelToNat(lev);
            D.print("log_query level filter: " # debug_show(test) # " " # debug_show(e.level));
            if (e.level < test) continue filter; }
        };
        buf.add(e);
        added += 1;
        if (added >= max) break filter;
      };
      Buffer.toArray(buf);
    };

    /// Remove all or selected log entries, return number dropped
    public func log_clear() : Nat {
      state.icrc85.activeActions += 1;

      let original = Vector.size(state.entries);
      switch (environment.onEvict) {
        case (?handler) {
          handler(Vector.toArray(state.entries));
        };
        case _ ()
      };
      Vector.clear(state.entries);
        
      
      let removed = original - Vector.size(state.entries);
      removed;
    };

    /// Export entire or filtered log as structure
    public func log_export(q: Service.LogQuery): Service.LogExportResult {
      let result = log_query(q);
      { exportedCount = result.size(); exported = result };
    };

    /// The log buffer size (optionally filtered)
    public func log_size(ns: ?[Text], lvl: ?MigrationTypes.Current.LogLevel): Nat {
      var n = 0;
      label count for (e in Vector.vals(state.entries)) {
        switch(ns) {
          case(null) {};
          case(?arr) { if (not inNamespaces(arr, e.namespace)) continue count; };
        };
        switch(lvl) {
          case(null) {};
          case(?lev) { 
            let test = levelToNat(lev);
            D.print("log_query level filter: " # debug_show(test) # " " # debug_show(e.level));
            if (e.level < test) continue count; }
        };
        n += 1;
      };
      n;
    };

    /// Set the maximum buffer size for the logger, returns new value
    public func log_set_buffer_size(v: Nat): Nat {
      if (v == 0) return state.bufferSize;
      state.bufferSize := v;
      // if log is oversized, truncate
      let curSize = Vector.size(state.entries);
      if (curSize > v) {
        ignore log_clear();
      };
      
      state.bufferSize;
    };

    public func log_set_min_level(level: MigrationTypes.Current.LogLevel): Nat {
      state.minLevel := ?level;
      levelToNat(level);
    };

    /// Get the maximum buffer size
    public func log_get_buffer_size(): Nat { state.bufferSize };
    

    ////////// ICRC85 OVS cycle sharing pattern /////////

    public func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
      switch (action.actionType) {
        case (ICRC85_Timer_Namespace) {
          await* ovsfixed.standardShareCycles({
            icrc_85_state = state.icrc85;
            icrc_85_environment = do?{environment.advanced!.icrc85!};
            setActionSync = environment.tt.setActionSync;
            timerNamespace = ICRC85_Timer_Namespace;
            paymentNamespace = ICRC85_Payment_Namespace;
            baseCycles = 200_000_000_000; // .2 XDR
            maxCycles = 1_000_000_000_000; // 1 XDR
            actionDivisor = 10000;
            actionMultiplier = 200_000_000_000; // .2 XDR
          });
          #awaited(id);
        };
        case (_) #trappable(id);
      };
    };

    public func getState() : MigrationTypes.Current.State {
      state;
    };

    public func getStats() : Stats {
      let stats : Stats = {
        tt = environment.tt.getStats();
        icrc85 = {
          nextCycleActionId = state.icrc85.nextCycleActionId;
          lastActionReported = state.icrc85.lastActionReported;
          activeActions = state.icrc85.activeActions;
        };
        bufferSize = state.bufferSize;
        minLevel = state.minLevel;
        log = Vector.toArray(state.entries);
      };
      stats;
    };
  };
};