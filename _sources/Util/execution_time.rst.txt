ExecutionTime
=============

The ``ExecutionTime`` module provides a simple mechanism for measuring the execution time of code
blocks and flagging times which exceed a hard-coded threshold (20ms for development environments
and 50ms otherwise). It leverages the ``ContextManager`` module to accomplish this in an ergonomic
way.

Example
-------

The following code is an example of how to use this module. ::

   local MyModule = select(2, ...).MyModule
   local ExecutionTime = MyModule:From("LibTSMUtil"):Include("Util.ExecutionTime")

   for _ in ExecutionTime.WithMeasurement("Count to 1M") do
      local x = 0
      while x < 1000000 do
         x = x + 1
      end
   end
   -- Warning log: Count to 1M took 0.12345s

API
---

.. lua:autoobject:: Util.ExecutionTime
   :members:
