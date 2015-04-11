-- decamp - distributed bugtracker
-- Copyright (C) 2015 Peter Harpending
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- | 
-- Module      : Data.Decamp.Trivia
-- Description : Trivia about decamp,
-- Copyright   : Copyright (C) 2015 Peter Harpending
-- License     : GPL-3
-- Maintainer  : Peter Harpending <peter@harpending.org>
-- Stability   : experimental
-- Portability : UNIX/GHC
-- 
-- This has stuff like the license and copyright

module Data.Decamp.Trivia where

import           Control.Monad ((<=<))
import           Data.ByteString (ByteString)
import qualified Data.ByteString as B
import           Data.Decamp.Internal
import           Data.Version (showVersion)
import           Paths_decamp (getDataFileName, version)
import           System.IO (hSetBinaryMode, stdout)

-- |The copyright notice
decampCopyright :: IO ByteString
decampCopyright =  readDataFile "res/copyright.txt"

-- |The tutorial
decampTutorial :: IO ByteString
decampTutorial =  readDataFile "TUTORIAL.md"

-- |The license (GPLv3)
decampLicense :: IO ByteString
decampLicense = readDataFile "LICENSE"

-- |The readme
decampReadme :: IO ByteString
decampReadme = readDataFile "README.md"

-- |The version
decampVersion :: String
decampVersion = showVersion version

-- |Print one of the 'ByteString's from above
printOut :: IO ByteString -> IO ()
printOut b = do
  hSetBinaryMode stdout True
  B.hPut stdout =<< b

-- |Print the version
printVersion :: IO ()
printVersion = putStrLn $ decampVersion
