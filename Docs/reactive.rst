Reactive Framework
==================

The Reactive Framework is one of the most powerful components of LibTSMUtil.

Theory of Operation
-------------------

The Reactive framework is based around observable state objects. One of the primary goals of
the Reactive framework is make it easy to build data-driven UI, where the UI can respond to
specific state fields being updated without needing to completely rerender the entire UI. For
example, if we have a UI that displays the player's current amount of gold, we only need to update
the text content when that value changes, rather than redrawing the entire window.
