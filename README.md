# stable-local-log: Motoko Logging Library

A powerful, modular logging infrastructure for Internet Computer (IC) projects. Designed to be instantiated once and shared across canisters or classes, providing namespace-based filtering, log levels, buffered storage, and upgrade-safe state management.

## Features

- **Shared, Central Logging**: Single logger instance across modules or canisters.
- **Buffered Ring Buffer**: Capped FIFO storage for log entries using `Vector`, with automatic rollover.
- **Namespace & Level Filtering**: Log by custom namespaces; filter by `Debug`, `Info`, `Warn`, `Error`, `Fatal`.
- **Flexible Querying**: Pagination via `take` and `prev`, plus namespace and level filters.
- **Export & Clear**: Retrieve or clear all or filtered logs for audit, analytics, or privacy.
- **Upgrade-Safe**: Built with versioned migrations to preserve logs across canister upgrades.
- **Extensibility Hooks**: `onEvict` callbacks for storing old data elsewhere.

## Installation

Add to your `mops.toml`:

`mops add stable-local-log`

Import in your Motoko module:
```motoko
import StableLocalLog "mo:stable-local-log";
```

## Instantiation (ClassPlus Pattern)

Use the `Init` helper from `ClassPlus` to create your logger instance. You must supply:

- `manager`: Your `ClassPlusInitializationManager`.
- `initialState`: `Local_log.initialState()` for default state.
- `args`: Optional `InitArgs` with `namespaces`, `min_level`, `bufferSize`.
- `pullEnvironment`: Function loader for `Environment` (required for cycle sharing).
- `onInitialize`: Optional async setup hook.
- `onStorageChange`: Hook invoked on state mutation.

Example:
```motoko
let mkLogger = Local_log.Init<system>({
  manager          = myManager;
  initialState     = Local_log.initialState();
  args             = ?{
    namespaces = ["app", "db"];         // default namespaces
    min_level  = ?#Info;                   // filter out Debug
    bufferSize = ?2000;                    // ring buffer max entries
  };
  pullEnvironment = ?(() -> {
    tt       = myTimerTool;
    advanced = null;
    onEvict  = ?(func(entry) { Debug.print("Evicted: " # entry.message); });
  });
  onInitialize    = ?(func _(logger) async { /* warm-up or migration */ });
  onStorageChange = func(state) { /* persist state or metrics */ };
});
let logger = mkLogger();
```

`logger` is now a callable function that returns your `Local_log` instance.

## API Reference

### Types

- **LogLevel**: `#Debug`, `#Info`, `#Warn`, `#Error`, `#Fatal`
- **LogEntry**:
  ```motoko
  { timestamp: Nat; message: Text; level: Nat; namespace: Text }
  ```
- **LogQuery**:
  ```motoko
  { namespaces: ?[Text]; level: ?LogLevel; take: ?Nat; prev: ?Nat }
  ```
- **LogExportResult**:
  ```motoko
  { exportedCount: Nat; exported: [LogEntry] }
  ```
- **InitArgs**:
  ```motoko
  { min_level: ?LogLevel; bufferSize: ?Nat }
  ```
- **Environment**:
  ```motoko
  { tt: TimerToolLib.TimerTool; advanced: ?{ icrc85: ICRC85Options }; onEvict: ?(LogEntry -> ()) }
  ```

### Public Methods

| Method                          | Params                                               | Returns               | Description                                 |
|---------------------------------|------------------------------------------------------|-----------------------|---------------------------------------------|
| `log_add`                       | `(message: Text, level: LogLevel, namespace: Text)`  | `()`                  | Add a log entry to one namespace           |
| `log_debug/info/warn/error/fatal` | `(message: Text, namespace: Text)`                  | `()`                  | Shortcut for `log_add` at respective level |
| `log_query`                     | `(q: LogQuery)`                                      | `[LogEntry]`          | Retrieve filtered/paginated logs           |
| `log_export`                    | `(q: LogQuery)`                                      | `LogExportResult`     | Export logs matching query                 |
| `log_clear`                     | `()`                                                 | `Nat`                 | Clear all entries and return count removed |
| `log_size`                      | `(namespaces: ?[Text], level: ?LogLevel)`            | `Nat`                 | Count entries matching filters             |
| `log_set_buffer_size`           | `(v: Nat)`                                           | `Nat`                 | Set max buffer size, truncate if needed    |
| `log_get_buffer_size`           | `()`                                                 | `Nat`                 | Get current buffer size                    |
| `log_set_min_level`             | `(level: LogLevel)`                                  | `Nat`                 | Set and return new minimum level           |
| `initialize_icrc85`             | `()`                                                 | `()`                  | Start OVS cycle-sharing timer & listeners  |
| `getState`                      | `()`                                                 | `State`               | Inspect internal state (for debug/migration)|

### Usage Examples

```motoko
// Add logs
logger().log_info("Service started", "app");
logger().log_error("Database error", "db");

// Query last 50 warnings or above
let recent = logger().log_query({ namespaces=null; level=?#Warn; take=?50; prev=null });

// Export and clear
let exportRes = await logger().log_export({ namespaces=null; level=null; take=null; prev=null });
ignore logger().log_clear();
```

## Advanced Topics

- **onEvict Callback**: Handle entries dropped by ring buffer rollover.
- **Upgrade Migrations**: Uses `Migration.migrate` to maintain state compatibility.
- **Cycle Sharing (ICRC85)**: Controlled via `initialize_icrc85` and `Environment.advanced` settings.

## Contributing

Contributions, issues, and pull requests are welcome! Please fork the repository and open a PR with your changes.

## License

This project is open-sourced under the MIT License. See the `LICENSE` file for details.

## License


## OVS Default Behavior

This motoko class has a default OVS behavior that sends cycles to the developer to provide funding for maintenance and continued development. In accordance with the OVS specification and ICRC85, this behavior may be overridden by another OVS sharing heuristic or turned off. We encourage all users to implement some form of OVS sharing as it helps us provide quality software and support to the community.

Default behavior: 0.2 XDR per 10000 processed events processed per month up to 1 XDR;

Default Beneficiary: PanIndustrial.com

Dependent Libraries: 
 - https://mops.one/timer-tool