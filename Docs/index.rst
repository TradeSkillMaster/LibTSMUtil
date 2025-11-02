LibTSMUtil
==========

LibTSMUtil provides many general utility functions and classes that have proven helpful when
writing complex WoW addons.

Dependencies
------------

This library has the following external dependencies which must be installed separately within the
target application:

* `LibTSMClass`_
* `LibTSMCore`_

It also embeds two libraries: `LibDeflate`_ and `LibSerialize`_.

.. _LibTSMClass: https://github.com/TradeSkillMaster/LibTSMClass
.. _LibTSMCore: https://github.com/TradeSkillMaster/LibTSMCore
.. _LibDeflate: https://github.com/SafeteeWoW/LibDeflate
.. _LibSerialize: https://github.com/rossnichols/LibSerialize

Installation
------------

If you're using the `BigWigs packager`_, you can reference LibTSMUtil as an external library.

.. code-block:: yaml

   externals:
      Libs/LibTSMUtil:
         url: https://github.com/TradeSkillMaster/LibTSMUtil.git

Otherwise, you can download the `latest release directly from GitHub`_.

.. _BigWigs packager: https://github.com/rossnichols/LibSerialize
.. _latest release directly from GitHub: https://github.com/TradeSkillMaster/LibTSMUtil/releases

Basic Usage
-----------

To use LibTSMUtil, add LibTSMUtil.xml to your .toc (or equivalent XML) and the ``LibTSMUtil``
component will be made available via LibTSMCore. ::

   -- App/Core.lua
   local ADDON_TABLE = select(2, ...)
   ADDON_TABLE.App = ADDON_TABLE.LibTSMCore.NewComponent("App")
      :AddDependency("LibTSMUtil")

You can then access the various modules and classes within ``LibTSMUtil``. ::

   -- App/UI.lua
   local App = select(2, ...).App
   local UI = App:Init("UI")
   local String = App:From("LibTSMUtil"):Include("Lua.String")
   local Log = App:From("LibTSMUtil"):Include("Util.Log")
   local SAVED_CHARACTERS_SEP = ","
   local private = {
      characters = {}
   }

   function App.LoadSavedCharacters(settingsStr)
      String.SafeSplit(settingsStr, SAVED_CHARACTERS_SEP, private.characters)
      for _, character in ipairs(private.characters) do
         Log.Info("Loaded character: %s", character)
      end
   end

Feature Summary
---------------

The features of LibTSMUtil are split across a few different modules:

* :doc:`Lua </Lua/index>` contains extensions on the various built-in Lua libraries and data types
* :doc:`BaseType </BaseType/index>` contains general utility classes and data types
* :doc:`Util </Util/index>` contains additional classes and modules which don't fit nicely into one
  of other modules
* :doc:`Format </Format/index>` contains modules for formatting and encoding data into a variety of
  string formats
* :doc:`UI </UI/index>` contains some UI-related utility classes and modules
* :doc:`FSM </fsm>` contains a finite state machine implementation

License and Contributions
-------------------------

LibTSMUtil is licensed under the MIT license. See LICENSE.txt for more information. If you would
like to contribute to LibTSMUtil, opening an issue or submitting a pull request against the
`LibTSMUtil GitHub project`_ is highly encouraged.

.. _LibTSMUtil GitHub project: https://github.com/TradeSkillMaster/LibTSMUtil


.. toctree::
   :hidden:

   Home <self>
   Lua/index
   BaseType/index
   Util/index
   Format/index
   UI/index
   fsm
