Context Manager
===============

The context manager module provides a python-like context manager syntax in Lua with a few
limitations. Specifically, using ``break`` or ``return`` within the context manager is not
supported due to the way Lua's GC works and the lack of any concrete way to trigger some cleanup
code to run when a variable loses scope.

Context managers can either be called standalone (as shown in the example below) in which case
the for loop block will be executed exactly once, with the enter and exit functions being called
before and after the loop respectively, or they can wrap another iterator, in which case the for
loop variables are passed through and the enter and exit functions are called before the first
iteration and after the last iteration respectively.

Example
-------

A common situation where context managers are helpful is to measure the execution time of a block
of code. LibTSMUtil provides the ``ExecutionTime`` module for this purpose, but below is a
simplified implemention to demonstration how the context manager module can be used. ::

   local MyModule = select(2, ...).MyModule
   local ContextManager = MyModule:From("LibTSMUtil"):Include("BaseType.ContextManager")

   local function EnterFunc(arg)
      print(format("Started block (%s)", arg))
      return LibTSMUtil.GetTime()
   end
   local function ExitFunc(arg, startTime)
      local elapsed = LibTSMUtil.GetTime() - startTime
      print(format("Completed block (%s) after %d seconds", arg, elapsed))
   end
   local measurementContextObj = ContextManager.Create(EnterFunc, ExitFunc)

   local sum = 0
   for _, value in measurementContextObj:With("CALCULATE_SUM", ipairs({1, 2, 3, 4, 5})) do
      sum = sum + value
   end

API
---

.. lua:autoobject:: BaseType.ContextManager
   :members:

.. lua:autoobject:: ContextManagerObject
   :members:
