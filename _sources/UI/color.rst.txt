Color
=====

The ``Color`` class provides methods for working with RGBA color values. The colors can easily be
converted between integer (0-255), floating point (0-1), and hex representations. The Color class
also makes it easy to change the tint of the color by first converting it to `HSLuv`_ and then
adjusting the lightness value.

.. _HSLuv: https://www.hsluv.org/

Example
-------

The following demonstrates a simple usage of the Color class. ::

   local MyModule = select(2, ...).MyModule
   local Color = MyModule:From("LibTSMUtil"):IncludeClassType("Color")

   local color = Color.NewFromHex("#a57f00")
   print(color:GetRGBA()) -- 165   127   0   255

   local darker = color:GetTint(-20)
   print(darker:GetHexNoAlpha()) -- #695000

Memory Management
-----------------

The ``Color`` objects are intended to never be GC'd and have a static lifecycle (i.e. one that's
equal to the lifecycle of the application), but there is nothing preventing them from being GC'd.

API
---

.. lua:autoobject:: Color
   :members:
