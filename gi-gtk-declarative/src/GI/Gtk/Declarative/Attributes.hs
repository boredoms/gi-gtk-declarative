{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}

{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE GADTs                  #-}
{-# LANGUAGE LambdaCase             #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE OverloadedLabels       #-}
{-# LANGUAGE TypeFamilies           #-}

-- | Attribute lists on declarative objects, supporting the underlying
-- attributes from "Data.GI.Base.Attributes", along with CSS class lists, and
-- pure and impure event callbacks.

module GI.Gtk.Declarative.Attributes
  ( Attribute(..)
  , classes
  , afterCreated
  -- * Event Handling
  , on
  , onM
  -- * Callbacks
  , Callback(..)
  )
where

import qualified Data.GI.Base.Attributes                            as GI
import qualified Data.GI.Base.Signals                               as GI
import qualified Data.HashSet                                       as HashSet
import qualified Data.Text                                          as T
import           Data.Typeable
import           GHC.TypeLits                                       (KnownSymbol,
                                                                     Symbol)
import qualified GI.Gtk                                             as Gtk

import           GI.Gtk.Declarative.Attributes.Internal.Callback
import           GI.Gtk.Declarative.Attributes.Internal.Conversions
import           GI.Gtk.Declarative.CSS

-- * Attributes

-- | The attribute GADT represent a supported attribute for a declarative
-- widget. This extends the regular notion of GTK+ attributes to also include
-- event handling and CSS classes.
data Attribute widget event where
  -- | An attribute/value mapping for a declarative widget. The
  -- 'GI.AttrLabelProxy' is parameterized by 'attr', which represents the
  -- GTK-defined attribute name. The underlying GI object needs to support
  -- the /construct/, /get/, and /set/ operations for the given attribute.
  (:=)
    :: (GI.AttrOpAllowed 'GI.AttrConstruct info widget
      , GI.AttrOpAllowed 'GI.AttrSet info widget
      , GI.AttrGetC info widget attr getValue
      , GI.AttrSetTypeConstraint info setValue
      , KnownSymbol attr
      , Typeable attr
      )
   => GI.AttrLabelProxy (attr :: Symbol) -> setValue -> Attribute widget event
  -- | Defines a set of CSS classes for the underlying widget's style context.
  -- Use the 'classes' function instead of this constructor directly.
  Classes
    :: Gtk.IsWidget widget
    => ClassSet
    -> Attribute widget event
  -- | Emit events using a pure callback. Use the 'on' function, instead of this
  -- constructor directly.
  OnSignalPure
    :: ( Gtk.GObject widget
       , GI.SignalInfo info
       , gtkCallback ~ GI.HaskellCallbackType info
       , ToGtkCallback gtkCallback Pure
       )
    => Gtk.SignalProxy widget info
    -> Callback gtkCallback widget Pure event
    -> Attribute widget event
  -- | Emit events using a pure callback. Use the 'on' function, instead of this
  -- constructor directly.
  OnSignalImpure
    :: ( Gtk.GObject widget
       , GI.SignalInfo info
       , gtkCallback ~ GI.HaskellCallbackType info
       , ToGtkCallback gtkCallback Impure
       )
    => Gtk.SignalProxy widget info
    -> Callback gtkCallback widget Impure event
    -> Attribute widget event
  -- | Provide a callback to modify the widget after it's been created.
  AfterCreated
    :: (widget -> IO ())
    -> Attribute widget event

-- | Attributes have a 'Functor' instance that maps events in all event
-- callbacks.
instance Functor (Attribute widget) where
  fmap f = \case
    attr := value -> attr := value
    Classes cs -> Classes cs
    OnSignalPure signal cb -> OnSignalPure signal (fmap f cb)
    OnSignalImpure signal cb -> OnSignalImpure signal (fmap f cb)
    AfterCreated cb -> AfterCreated cb

-- | Define the CSS classes for the underlying widget's style context. For these
-- classes to have any effect, this requires a 'Gtk.CssProvider' with CSS files
-- loaded, to be added to the GDK screen. You probably want to do this in your
-- entry point when setting up GTK.
classes :: Gtk.IsWidget widget => [T.Text] -> Attribute widget event
classes = Classes . HashSet.fromList

-- | Emit events, using a pure callback, by subcribing to the specified
-- signal.
on
  :: ( Gtk.GObject widget
     , GI.SignalInfo info
     , gtkCallback ~ GI.HaskellCallbackType info
     , ToGtkCallback gtkCallback Pure
     , ToCallback gtkCallback widget Pure
     , userCallback ~ UserCallback gtkCallback widget Pure event
     )
  => Gtk.SignalProxy widget info
  -> userCallback
  -> Attribute widget event
on signal = OnSignalPure signal . toCallback

-- | Emit events, using an impure callback receiving the 'widget' and returning
-- an 'IO' action of 'event', by subcribing to the specified signal.
onM
  :: ( Gtk.GObject widget
     , GI.SignalInfo info
     , gtkCallback ~ GI.HaskellCallbackType info
     , ToGtkCallback gtkCallback Impure
     , ToCallback gtkCallback widget Impure
     , userCallback ~ UserCallback gtkCallback widget Impure event
     )
  => Gtk.SignalProxy widget info
  -> userCallback
  -> Attribute widget event
onM signal = OnSignalImpure signal . toCallback

-- | Provide a callback to modify the widget after it's been created.
afterCreated :: (widget -> IO ()) -> Attribute widget event
afterCreated = AfterCreated
