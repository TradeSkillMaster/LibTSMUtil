CSV
===

The ``CSV`` module provides functions to encode and decode CSV data.

Example
-------

The following code demonstrates how to encode and decode CSV data. ::

   local MyModule = select(2, ...).MyModule
   local CSV = MyModule:From("LibTSMUtil"):Include("Format.CSV")
   local FIELDS = {"name", "class", "level"}

   local encodeContext = CSV.EncodeStart(FIELDS)
   CSV.EncodeAddRowDataRaw(encodeContext, "Player1", "Monk", 15)
   CSV.EncodeAddRowDataRaw(encodeContext, "Player2", "Mage", 28)
   local csvData = CSV.EncodeEnd(encodeContext)
   print(csvData) -- name,class,level\nPlayer1,Monk,15\nPlayer2,Mage,28

   local decodeContext = CSV.DecodeStart(csvData, FIELDS)
   for name, class, level in CSV.DecodeIterator(decodeContext) do
      print(name, class, level)
   end
   -- Player1   Monk   15
   -- Player2   Mage   28
   CSV.DecodeEnd(decodeContext)

API
---

.. lua:autoobject:: Format.CSV
   :members:
