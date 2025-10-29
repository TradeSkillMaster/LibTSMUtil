String Builder
==============

The ``StringBuilder`` class provides a templating system for building complex strings with
paramters defined at runtime. Parameters are inserted into format strings and surrounded by parens.
The advantage over normal format strings is that parameters can be more explicitly defined and
there can be runtime checks to ensure that they are properly specified.

Example
-------

The following code demonstrates using the StringBuilder class and setting parameters. ::

   local MyModule = select(2, ...).MyModule
   local StringBuilder = MyModule:From("LibTSMUtil"):IncludeClassType("StringBuilder")

   local builder = StringBuilder.Create()
   local str = builder:SetTemplate("Hello %(name)s, your number is %(num)d.")
      :SetParam("name", "LibTSMUtil")
      :SetParam("num", 42)
      :Commit()
   print(str) -- Hello LibTSMUtil, your number is 42.

API
---

.. lua:autoobject:: StringBuilder
   :members:
