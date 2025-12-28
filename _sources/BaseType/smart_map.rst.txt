Smart Map
=========

The ``SmartMap`` class provides a simple way to cache the values of an arbitrary mapping function.
This is useful when there is some expensive operation that is regularly performed on a specific
set of values and caching the result gives a significant performance improvement. There is also a
mechanism to invalidate the whole cache, as well as just specific keys.

Example
-------

Below is an example which demonstrates how to use the ``SmartMap`` class. ::

   local MyModule = select(2, ...).MyModule
   local SmartMap = MyModule:From("LibTSMUtil"):IncludeClassType("SmartMap")

   local function LookupValue(key)
      -- Assume this is an expensive and non-trivial operation
      return strupper(key)
   end

   local map = SmartMap.New("string", "string", LookupValue)

   local reader = map:CreateReader(function(_, pendingChanges)
      for key, prevValue in pairs(pendingChanges) do print("CHANGE", key, prevValue) end
   end)
   print(reader["a"]) -- A
   print(reader["b"]) -- B

   -- Invalidate the mapping for just one key
   map:ValueChanged("a")
   -- CHANGE   a   A

   -- Invalidate the entire map if the underlying operation changes significantly
   map:Invalidate()
   -- CHANGE   b   B

Memory Management
-----------------

Both ``SmartMap`` and ``SmartMapReader`` objects are intended to never be GC'd and have a static
lifecycle (i.e. one that's equal to the lifecycle of the application).

API
---

.. lua:autoobject:: SmartMap
   :members:
