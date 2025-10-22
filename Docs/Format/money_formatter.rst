Money Formatter
===============

The ``MoneyFormatter`` class makes it easy to create human-readable representions of money values
in WoW.

Foramts
-------

The following formats can be set via the ``:SetFormat()`` method. They are available via the
``MoneyFormatter.FORMAT`` enum.

* ``MoneyFormatter.FORMAT.TEXT`` - Use colored "g"/"s"/"c" text strings for denominations.
* ``MoneyFormatter.FORMAT.TEXT_DISABLED`` - Use colored (with a disabled tint) "g"/"s"/"c" text
  strings for denominations.
* ``MoneyFormatter.FORMAT.ICON`` - Use gold/silver/copper texture icons.
* ``MoneyFormatter.FORMAT.TEXT_DISABLED`` - Use gold/silver/copper texture icons with a disabled
  tint.

Copper Handling
---------------

In many situations, the copper values is not worth displaying. The following behaviors are made
available via the ``MoneyFormatter.COPPER_HANDLING`` enum and can be set via the
``:SetCopperHandling()`` method.

* ``MoneyFormatter.COPPER_HANDLING.KEEP`` - Always display the copper value.
* ``MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G`` - Round to the nearest silver if the value is
  greater than 1 gold. Also removes the copper value if it's 0.
* ``MoneyFormatter.COPPER_HANDLING.REMOVE`` - Always remove the copper value.

API
---

.. lua:autoobject:: MoneyFormatter
   :members:
