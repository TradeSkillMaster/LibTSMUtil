Log
===

The ``Log`` module provides a set of logging APIs for debugging purposes. The logging module has
the following features:

* A total of 3 log levels are supported for general purpose log messages: ``INFO``, ``WARN``, and
  ``ERR``.
* The file name and line number are captured with each log message.
* Logging to chat can be enabled via the ``Log.SetLoggingToChatEnabled()`` API and includes colored
  severity levels.
* A buffer of the most recent 200 log entries is kept for potential retrieval latter (i.e. from an
  error handler).

Example
-------

The following demonstrates a simple usage of this module. ::

   -- Demo.lua
   local MyModule = select(2, ...).MyModule
   local ExecutionTime = MyModule:From("LibTSMUtil"):Include("Util.Log")

   Log.Info("My favorite number is %d", random(0, 100))
   -- 12:15:24.615 [INFO] {Demo.lua:4} My favorite number is 42

API
---

.. lua:autoobject:: Util.Log
   :members:
