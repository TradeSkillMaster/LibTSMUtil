# Log

The `Log` module provides a set of logging APIs for debugging purposes:

* A total of 3 log levels are supported: `INFO`, `WARN`, and `ERR`.
* The file name and line number are captured with each log message.
* Logging to chat can be enabled via `Log.SetLoggingToChatEnabled()` and includes colored severity levels.
* A buffer of the most recent 200 log entries is kept for potential retrieval later (i.e. from an error handler).

## Example

```lua
-- Demo.lua
local MyModule = select(2, ...).MyModule
local Log = MyModule:From("LibTSMUtil"):Include("Util.Log")

Log.Info("My favorite number is %d", random(0, 100))
-- 12:15:24.615 [INFO] {Demo.lua:4} My favorite number is 42
```

## API

<!--@include: ./api/Util.Log.md-->
