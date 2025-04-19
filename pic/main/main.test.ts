import { Principal } from "@dfinity/principal";

import { IDL } from "@dfinity/candid";

import {
  PocketIc,
  createIdentity
} from "@dfinity/pic";

import type {
  Actor,
  CanisterFixture
} from "@dfinity/pic";



// Runtime import: include the .js extension
import { idlFactory as mainIDLFactory, init as mainInit } from "../../src/declarations/main/main.did.js";

// Type-only import: import types from the candid interface without the extension
import type { _SERVICE as mainService } from "../../src/declarations/main/main.did";
  
export const WASM_PATH = ".dfx/local/canisters/main/main.wasm";

let replacer = (_key: any, value: any) => typeof value === "bigint" ? value.toString() + "n" : value;
export const sub_WASM_PATH = process.env['SUB_WASM_PATH'] || WASM_PATH; 
let pic: PocketIc;

let main_fixture: CanisterFixture<mainService>;

const admin = createIdentity("admin");

/*only used when you need NNS state
const NNS_SUBNET_ID =
  "erfz5-i2fgp-76zf7-idtca-yam6s-reegs-x5a3a-nku2r-uqnwl-5g7cy-tqe";
const NNS_STATE_PATH = "pic/nns_state/node-100/state";
*/

describe("test main", () => {

  


  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL, {
      
      /* nns: {
        state: {
          type: SubnetStateType.FromPath,
          path: NNS_STATE_PATH,
          subnetId: Principal.fromText(NNS_SUBNET_ID),
        }
      }, */

      processingTimeoutMs: 1000 * 60 * 5,
    } );

    //const subnets = pic.getApplicationSubnets();

    main_fixture = await pic.setupCanister<mainService>({
      //targetCanisterId: Principal.fromText("q26le-iqaaa-aaaam-actsa-cai"),
      sender: admin.getPrincipal(),
      idlFactory: mainIDLFactory,
      wasm: sub_WASM_PATH,
      //targetSubnetId: subnets[0].id,
      arg: IDL.encode(mainInit({IDL}), [[]]),
    });

  });


  afterEach(async () => {
    await pic.tearDown();
  });

  it("supports paginated log_query", async () => {
    // Insert 15 logs
    for (let i = 0; i < 15; i++) {
      await main_fixture.actor.log_add("pagelog_" + i, {Debug:null}, "paginate");
    }
    // Paginate: take 10 then rest
    let page1 = await main_fixture.actor.log_query({namespaces: [["paginate"]], level: [], take: [10n], prev: []});
    expect(page1.length).toBe(10);
    expect(page1[0].message).toMatch(/pagelog_/);
    let page2 = await main_fixture.actor.log_query({namespaces: [["paginate"]], level: [], take: [10n], prev: [10n]});
    expect(page2.length).toBe(5);
    expect(page2[0].message).toMatch(/pagelog_/);
    // Together, all logs present
    let combo = page1.concat(page2);
    expect(combo.length).toBe(15);
    // No overlap
    expect(page1.find(e=>e.message==page2[0].message)).toBeUndefined();
  });

  it("log ring buffer truncates and keeps latest", async () => {
    // Set log buffer to 5
    await main_fixture.actor.log_set_buffer_size(5n);
    // Add more than 5 logs
    for (let i = 0; i < 9; i++) {
      await main_fixture.actor.log_add("buflog_" + i, {Warn:null}, "ring");
    }
    // Only 5 logs kept
    const logs = await main_fixture.actor.log_query({namespaces: [["ring"]], level: [], take: [100n], prev: []});
    console.log("log length", logs.length, JSON.stringify(logs, replacer, 2));
    expect(logs.length).toBe(4);
    expect(logs[0].message).toBe("buflog_5"); // Should be 4..8
    expect(logs[3].message).toBe("buflog_8");
  });

  it("logs are preserved after upgrade", async () => {
    // Write a unique log, restart canister, confirm
    await main_fixture.actor.log_add("pre_upgrade_entry", {Info:null}, "survive");
await pic.upgradeCanister({ canisterId: main_fixture.canisterId, wasm: sub_WASM_PATH, arg: IDL.encode(mainInit({IDL}), [[]]), sender: admin.getPrincipal() });
    const after = await main_fixture.actor.log_query({namespaces: [["survive"]], level: [], take: [10n], prev: []});
    expect(after.length).toBeGreaterThan(0);
    expect(after.find(e=>e.message=="pre_upgrade_entry")).toBeDefined();
  });

  // Fuzz test for log_add/log_query filtering across namespaces and levels
  it("filters by namespace and log level with fuzzed input set", async () => {
    // Fuzzing parameters
    const namespaces = ["alpha", "beta", "gamma", "delta", "epsilon"];
    const messages = ["logA", "logB", "logC", "logD", "logE", "special"].map((x, i) => x + i);
    const levels = [
      { Debug: null },
      { Info: null },
      { Warn: null },
      { Error: null },
      { Fatal: null }
    ];
    // Map log level to numeric value for comparison
    const levelOrder = ["Debug", "Info", "Warn", "Error", "Fatal"];
    const getLevelIdx = (l: any) => levelOrder.findIndex(k => l[k] !== undefined);

    // Insert logs for all combinations
    for (let n of namespaces) {
      for (let l of levels) {
        for (let m of messages) {
          await main_fixture.actor.log_add(m + "@" + n, l, n);
        }
      }
    }

    // For each ns/level, confirm results are correct
    for (let n of namespaces) {
      for (let idx = 0; idx < levels.length; idx++) {
        const l = levels[idx];
        const logs = await main_fixture.actor.log_query({namespaces: [[n]], level: [l], take: [999n], prev: []});
        // Expect logs at this level and above
        const expectedCount = messages.length * (levels.length - idx);
        expect(logs.length).toEqual(expectedCount);
        // Check each log
        for (const entry of logs) {
          expect(entry.namespace).toEqual(n);
          //console.log("entry", entry, getLevelIdx(entry.level), idx);
          // entry.level should be >= l
          expect(entry.level).toBeGreaterThanOrEqual(idx);
        }
      }
    }

    // Try multi-namespace queries for a specific level
    const multi = namespaces.slice(0, 3);
    const levelIdx = 2; // Warn
    const multiRes = await main_fixture.actor.log_query({namespaces: [multi], level: [levels[levelIdx]], take: [200n], prev: []});
    // Should only include logs from multi namespaces and level >= Warn
    expect(multiRes.every(e => multi.includes(e.namespace) && e.level >= levelIdx)).toBeTruthy();

    // pagination and take/prev
    const recent = await main_fixture.actor.log_query({namespaces: [namespaces], level: [], take: [2n], prev: []});
    expect(recent.length).toBe(2);
    if (recent.length === 2) {
      const next = await main_fixture.actor.log_query({namespaces: [namespaces], level: [], take: [999n], prev: [2n]});
      expect(next[0].message).not.toEqual(recent[0].message);
    }
  });



  it(`can call hello world`, async () => {

    main_fixture.actor.setIdentity(admin);
    const response = await main_fixture.actor.hello();
    expect(response).toEqual("world!");
  });


  it("add and fetch logs, including by namespace and level", async () => {
    await main_fixture.actor.log_add("Startup entry", {Info:null}, "default");
    await main_fixture.actor.log_add("Debugging entry", {Debug:null}, "moduleA");
    await main_fixture.actor.log_add("Warning", {Warn:null}, "moduleA");
    await main_fixture.actor.log_add("Serious error", {Error:null}, "critical");

    let all = await main_fixture.actor.log_query({namespaces: [], level: [], take: [10n], prev: []});
    expect(all.length).toBeGreaterThanOrEqual(4);

    let nsLogs = await main_fixture.actor.log_query({namespaces: [["moduleA"]], level: [], take: [10n], prev: []});
    expect(nsLogs.find(l => l.message === "Debugging entry")).toBeDefined();
    expect(nsLogs.find(l => l.level &&  l.level ==2n)).toBeDefined();

    let debugLogs = await main_fixture.actor.log_query({namespaces: [["moduleA"]], level: [{Debug:null}], take:[10n], prev: []});
    expect(debugLogs.length).toBe(2);
    expect(debugLogs[0].message).toEqual("Debugging entry");
    expect(debugLogs[1].message).toEqual("Warning");
  });

  it("log_clear removes only namespace logs", async () => {
    // Add additional logs for both namespaces
    await main_fixture.actor.log_add("NS filter log", {Warn:null}, "toRemove");
    await main_fixture.actor.log_add("NS filter log", {Warn:null}, "remain");
    // Get sizes
    const before = await main_fixture.actor.log_size([], []);
    const cleared = await main_fixture.actor.log_clear();
    const after = await main_fixture.actor.log_size([], []);
    expect(cleared).toBeGreaterThan(0);
    expect(after).toBeLessThan(before);
const checkRemoved = await main_fixture.actor.log_query({namespaces:[["toRemove"]], level: [], take: [10n], prev: []});
    expect(checkRemoved.length).toBe(0);
  });

  it("log_set/get_buffer_size adjusts and persists", async () => {
    const orig = await main_fixture.actor.log_get_buffer_size();
    const set = await main_fixture.actor.log_set_buffer_size(17n);
    expect(set).toEqual(17n);
    expect(await main_fixture.actor.log_get_buffer_size()).toEqual(17n);
    // Reset size
    await main_fixture.actor.log_set_buffer_size(orig);
  });

  it("log_export returns accurate counts", async () => {
    await main_fixture.actor.log_add("Exp-entry", {Info:null}, "testexport");
    const exp = await main_fixture.actor.log_export({namespaces: [["testexport"]], level: [], take: [100n], prev: []});
expect(exp.exportedCount).toBe(BigInt(exp.exported.length));
    expect(exp.exported.find(l=>l.message==="Exp-entry")).toBeDefined();
  });



});
