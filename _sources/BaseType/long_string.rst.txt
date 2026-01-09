Long String
===========

When saving large amounts of serialized data to WoW's SavedVariables files, it's common to run into
issues where very large strings aren't saved properly. The ``LongString`` module provides a simple
solution to this by internally splitting the string and storing it as a list of smaller strings. It
also leverages the ``Encoder`` module to compress the string and encode it as base64.

API
---

.. lua:autoobject:: BaseType.LongString
   :members:
