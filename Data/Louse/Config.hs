-- louse - distributed bugtracker
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
-- Module      : Data.Louse.Config
-- Description : Louse's configuration file
-- Copyright   : Copyright (C) 2015 Peter Harpending
-- License     : GPL-3
-- Maintainer  : Peter Harpending <peter@harpending.org>
-- Stability   : experimental
-- Portability : UNIX/GHC
-- 
-- This module reads louse's configuration file, and parses it into a
-- 'LouseConfig' object.

module Data.Louse.Config where

import Control.Monad.Trans.Resource (runResourceT)
import Data.Aeson
import Data.Conduit
import Data.Conduit.Attoparsec
import Data.Conduit.Binary
import Data.Louse.DataFiles
import Data.Louse.Types
import System.Directory

readLouseConfig :: IO (Maybe LouseConfig)
readLouseConfig = pure Nothing
  -- do configPath <- _config_path
  --    -- configPathExists <- doesFileExist configPath
  --    -- case configPathExists of
  --    -- False -> pure Nothing
  --    -- True ->
  --    return Nothing
     -- fmap
     --   Just
     --   (parseMonad =<<
     --    (runResourceT
     --       (connect (sourceFile configPath)
     --                (sinkParser json))))

writeLouseConfig :: LouseConfig -> IO ()
writeLouseConfig cfg =
  do configPath <- _config_path
     runResourceT
       (connect (sourceLbs (encode cfg))
                (sinkFile configPath))