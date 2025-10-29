CallbackRegistry
================

The ``CallbackRegistry`` class provides an easy mechanism to register and dispatch callbacks. It
can be used in two different modes: either as a list or with keys.

List
----

A list callback registry calls the callbacks in the order they were registered. ::

   local MyModule = select(2, ...).MyModule
   local CallbackRegistry = MyModule:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")

   local function Callback1(value)
      print("CALLBACK1", value)
   end
   local function Callback2(value)
      print("CALLBACK2", value)
   end

   local registry = CallbackRegistry.NewList()
   registry:Add(Callback1)
   registry:Add(Callback2)

   registry:CallAll(98)
   -- CALLBACK 1  98
   -- CALLBACK 2  98

   registry:Remove(Callback2)

   registry:CallAll(14)
   -- CALLBACK 1  14

Keys
-----------

A keys callback registry calls the callbacks in an arbitrary order, but allows calling a specific
callback. ::

   local MyModule = select(2, ...).MyModule
   local CallbackRegistry = MyModule:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")

   local function Callback1(value)
      print("CALLBACK1", value)
   end
   local function Callback2(value)
      print("CALLBACK2", value)
   end

   local registry = CallbackRegistry.NewWithKeys()
   registry:Add(Callback1, "1")
   registry:Add(Callback2, "2")

   registry:CallAll(98)
   -- CALLBACK 1  98
   -- CALLBACK 2  98

   registry:Call("1", 14)
   -- CALLBACK 1  14

API
---

.. lua:autoobject:: CallbackRegistry
   :members:
