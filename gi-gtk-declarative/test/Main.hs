module Main where

import           Control.Concurrent
import           Control.Monad
import qualified GI.Gtk                              as Gtk
import           System.Exit
import           System.IO

import qualified GI.Gtk.Declarative.CustomWidgetTest as CustomWidget


main :: IO ()
main = do
  _ <- Gtk.init Nothing
  _ <- forkOS $ do
    results <- sequence [CustomWidget.tests]
    Gtk.mainQuit
    unless (and results) $ do
      hPutStrLn stderr "Tests failed."
      exitFailure
  Gtk.main

