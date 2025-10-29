Encoder
=======

The ``Encoder`` class makes it easy to serialize and deserialize data for a variety of purposes.
This class **optionally** depends on the ``C_EncodingUtil`` APIs provided by WoW, but LibTSMUtil
also provides its own implementation for non-WoW environments with the help of the embedded
`LibDeflate`_ and `LibSerialize`_ libraries. The only limitation in a non-WoW environment is that
CBOR is not supported, which can be detected at runtime via the ``Encoder.SupportsCBOR()`` static
function.

The serialization process performs 3 steps:

#. **Serialization** - There are 3 different serialization types: ``"FAST"``,  ``"STABLE"``,
   and ``"CBOR"`` or ``"NONE"`` can be specified to skip serialization entirely. The ``"FAST"`` and
   ``"STABLE"`` options leverage `LibSerialize`_, with the former setting the ``stable`` option to
   to ensure that the result is stable, even for key-value tables. The
   ``:SetSerializationFilter()`` method allows for specifying the ``filter`` option to pass to
   `LibSerialize`_. The last option leverages WoW's ``C_EncodingUtil`` APIs for CBOR encoding.

#. **Compression** - Compression is achieved either via WoW's ``C_EncodingUtil`` APIs or
   `LibDeflate`_ to compress the data.

#. **Encoding** - The resulting string is then encoded based on how it will be ultiized with three
   options being available: ``"PRINT"`` for ensuring the result is safely printable (via
   ``LibDeflate:EncodeForPrint()``), ``"ADDON"`` for ensuring the result can be sent over the
   in-game addon comms channel (via ``LibDeflate:EncodeForWoWAddonChannel()``), and ``"BASE64"``
   for base64 encoding using the standard alphabet (includes "+" and "/").

The deserialization process simply reverses the order of the 3 steps listed above.

.. _LibDeflate: https://github.com/SafeteeWoW/LibDeflate
.. _LibSerialize: https://github.com/rossnichols/LibSerialize

Example
-------

Here's some code that shows how serialization and deserialization of data could be used to
implement an RPC mechanism. ::

   local MyModule = select(2, ...).MyModule
   local Encoder = MyModule:From("LibTSMUtil"):IncludeClassType("Encoder")

   local encoder = Encoder.Create()
      :SetEncodingType("ADDON")
      :SetSerializationType("FAST")

   local request = encoder:Serialize("SWAP_ORDER", 11, 62)

   local response = SendRequest(request) -- assume this is defined elsewhere

   local success, result1, result2 = encoder:Deserialize(response)
   assert(success)
   print(result1, result2) -- 62    11

API
---

.. lua:autoobject:: Encoder
   :members:
