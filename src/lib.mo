import MigrationTypes "migrations/types";
import MigrationLib "migrations";
import ClassPlusLib "mo:class-plus";
import Buffer "mo:base/Buffer";
import Service "service";
import D "mo:base/Debug";
import Star "mo:star/star";
import ovsfixed "mo:ovs-fixed";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Map "mo:map/Map";



module {

  public let Migration = MigrationLib;
  public let TT = MigrationLib.TimerTool;
  public type State = MigrationTypes.State;
  public type CurrentState = MigrationTypes.Current.State;
  public type Environment = MigrationTypes.Current.Environment;
  public type InitArgs = MigrationTypes.Current.InitArgs;

  public let init = Migration.migrate;

  public func initialState() : State {#v0_0_0(#data)};
  public let currentStateVersion = #v0_1_0(#id);


  public func test() : Nat{
    1;
  };

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(Local_log -> async*());
    onStorageChange : ((State) ->())
  }) :()-> Local_log {

    D.print("Subscriber Init");
    switch(config.pullEnvironment){
      case(?val) {
        D.print("pull environment has value");
        
      };
      case(null) {
        D.print("pull environment is null");
      };
    };  
    ClassPlusLib.ClassPlus<system,
      Local_log, 
      State,
      InitArgs,
      Environment>({config with constructor = Local_log}).get;
  };

  public class Local_log(stored: ?State, caller: Principal, canister: Principal, args: ?InitArgs, environment_passed: ?Environment, storageChanged: (State) -> ()){

    public let debug_channel = {
      var announce = true;
    };

    public var vecLog = Buffer.Buffer<Text>(1);

    private func d(doLog : Bool, message: Text) {
      if(doLog){
        vecLog.add( Nat.toText(Int.abs(Time.now())) # " " # message);
        if(vecLog.size() > 5000){
          vecLog := Buffer.Buffer<Text>(1);
        };
        D.print(message);
      };
    };

    let environment = switch(environment_passed){
      case(?val) val;
      case(null) {
        D.trap("Environment is required");
      };
    };

    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, null, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, null, canister);
        foundState;
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    let self : Service.Service = actor(Principal.toText(canister));


    ///////////
    // ICRC85 ovs
    //////////

    private var _icrc85init = false;

    private func ensureCycleShare<system>() : async*(){
      if(_icrc85init == true) return;
      _icrc85init := true;

      ignore Timer.setTimer<system>(#nanoseconds(OneDay), scheduleCycleShare);
      environment.tt.registerExecutionListenerAsync(?"icrc85:ovs:shareaction:local_log", handleIcrc85Action : TT.ExecutionAsyncHandler);
    };

    private func scheduleCycleShare<system>() : async() {
      //check to see if it already exists
      debug d(debug_channel.announce, "in schedule cycle share");
      switch(state.icrc85.nextCycleActionId){
        case(?val){
          switch(Map.get(environment.tt.getState().actionIdIndex, Map.nhash, val)){
            case(?time) {
              //already in the queue
              return;
            };
            case(null) {};
          };
        };
        case(null){};
      };



      let result = environment.tt.setActionSync<system>(Int.abs(Time.now()), ({actionType = "icrc85:ovs:shareaction:local_log"; params = Blob.fromArray([]);}));
      state.icrc85.nextCycleActionId := ?result.id;
    };

    private func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error>{

      D.print("in handle timer async " # debug_show((id,action)));
      switch(action.actionType){
        case("icrc85:ovs:shareaction:local_log"){
          await* shareCycles<system>();
          #awaited(id);
        };
        case(_) #trappable(id);
      };
    };

    private func shareCycles<system>() : async*(){
      debug d(debug_channel.announce, "in share cycles ");
      let lastReportId = switch(state.icrc85.lastActionReported){
        case(?val) val;
        case(null) 0;
      };

      debug d(debug_channel.announce, "last report id " # debug_show(lastReportId));

      let actions = if(state.icrc85.activeActions > 0){
        state.icrc85.activeActions;
      } else {1;};

      state.icrc85.activeActions := 0;

      debug d(debug_channel.announce, "actions " # debug_show(actions));

      var cyclesToShare = 1_000_000_000_000; //1 XDR

      if(actions > 0){
        let additional = Nat.div(actions, 10000);
        debug d(debug_channel.announce, "additional " # debug_show(additional));
        cyclesToShare := cyclesToShare + (additional * 1_000_000_000_000);
        if(cyclesToShare > 100_000_000_000_000) cyclesToShare := 100_000_000_000_000;
      };

      debug d(debug_channel.announce, "cycles to share" # debug_show(cyclesToShare));

      try{
        await* ovsfixed.shareCycles<system>({
          environment = do?{environment.advanced!.icrc85!};
          namespace = "com.icdevs.libraries.local_log";
          actions = actions;
          schedule = func <system>(period: Nat) : async* (){
            let result = environment.tt.setActionSync<system>(Int.abs(Time.now()) + period, {actionType = "icrc85:ovs:shareaction:local_log"; params = Blob.fromArray([]);});
            state.icrc85.nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
      } catch(e){
        debug d(debug_channel.announce, "error sharing cycles" # Error.message(e));
      };

    };

    let OneDay =  86_400_000_000_000;


  };

};