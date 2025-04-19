module {
  /// LogLevel describes the severity or type of the log entry.
  public type LogLevel = {
    #Debug;
    #Info;
    #Warn;
    #Error;
    #Fatal;
  };

  /// LogEntry represents a single log entry in the local log.
  public type LogEntry = {
    timestamp: Nat; // Int.abs(Time.now()), i.e. nanoseconds since epoch
    message: Text;
    level: Nat;
    namespace: Text;
  };

  /// LogQuery allows querying logs by namespace, log level and optionally by time range (future extension)
  public type LogQuery = {
    namespaces: ?[Text]; // null means all
    level: ?LogLevel;    // null means all
    take: ?Nat;          // max number to return (null = default/max)
    prev: ?Nat;          // return entries after a log index (for pagination)
  };

  /// LogExportResult is a structure returned when exporting/saving logs externally (future extension for streaming/log saving functionality)
  public type LogExportResult = {
    exportedCount: Nat;
    exported: [LogEntry];
  };

  /// Service: actor interface for local log module
  public type Service = actor {
    // Add a log entry, to one namespace or many
    log_add: (message: Text, level: LogLevel, namespaces: [Text]) -> async () ;

    // Query log entries (with filter/pagination)
    log_query: (q: LogQuery) -> async [LogEntry];

    // Clear all log entries (optionally by namespace or all)
    log_clear : (?[Text]) -> async Nat;

    // Export the log, optionally with filters (future extension would support streaming large logs)
    log_export: (q: LogQuery) -> async LogExportResult;

    // Get the number of log entries in buffer (optionally filtered)
    log_size: (?[Text], ?LogLevel) -> async Nat;

    // Set or get the log buffer max size (for rollover)
    log_set_buffer_size: (Nat) -> async Nat; // returns new value
    log_get_buffer_size: () -> async Nat;
  };

};