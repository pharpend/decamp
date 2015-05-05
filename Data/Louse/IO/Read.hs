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
-- Module      : Data.Louse.IO.Read
-- Description : 'readLouse' and Friends
-- Copyright   : Copyright (C) 2015 Peter Harpending
-- License     : GPL-3
-- Maintainer  : Peter Harpending <peter@harpending.org>
-- Stability   : experimental
-- Portability : UNIX/GHC
-- 

module Data.Louse.IO.Read where

import           Control.Exception
import           Control.Monad
import           Data.Aeson
import qualified Data.ByteString as Bs
import qualified Data.ByteString.Lazy as Bl
import           Data.Louse.IO.DataFiles
import           Data.Monoid
import qualified Data.Map as M
import           Data.List.Utils (split)
import           Data.Louse.Types
import           Data.Ratio ((%))
import qualified Data.Text as T
import           Safe
import           System.Directory
import           System.Exit (exitFailure)
import           System.IO (hPutStrLn, stderr)
import           System.IO.Error
import           Text.Editor

-- |Read the 'Louse' from the current directory
-- 
-- > readLouse = readLouseFrom =<< getCurrentDirectory
-- 
readLouse :: IO (Either String Louse)
readLouse = readLouseFrom =<< getCurrentDirectory

-- |Read the 'Louse' from the current directory
-- 
-- > readLouseMay = readLouseFromMay =<< getCurrentDirectory
-- 
readLouseMay :: IO (Maybe Louse)
readLouseMay = readLouseFromMay =<< getCurrentDirectory

-- |Read the 'Louse' from the current directory
-- 
-- > readLouseErr = readLouseFromErr =<< getCurrentDirectory
-- 
readLouseErr :: IO Louse
readLouseErr = readLouseFromErr =<< getCurrentDirectory

-- |Wrapper around 'readLouseFromErr', which catches errors, and returns
-- a 'Left' if there is an error.
readLouseFrom 
  :: FilePath                   -- ^The working directory
  -> IO (Either String Louse)
readLouseFrom fp = (try (readLouseFromErr fp) :: IO (Either SomeException Louse)) >>= \case
                     Left err -> pure (Left (show err))
                     Right x  -> pure (Right x)

-- |Wrapper around 'readLouseFromErr', which returns 'Nothing' if there
-- is an error.
readLouseFromMay 
  :: FilePath         -- ^The working directory
  -> IO (Maybe Louse)
readLouseFromMay = readLouseFrom >=> \case
                     Left _  -> pure Nothing
                     Right x -> pure (Just x)

-- |This is a function to read the Louse instance from a directory.
readLouseFromErr 
  :: FilePath -- ^The path to the project directory (i.e. NOT .louse)
  -> IO Louse -- ^The resulting 'Louse'
readLouseFromErr fp = do
  prjInfoExists <- doesFileExist (fp <> _project_json)
  prjInfoBS <- if | prjInfoExists -> Just <$> Bl.readFile (fp <> _project_json)
                  | otherwise -> pure Nothing
  prjInfo <- case eitherDecode <$> prjInfoBS of
               Nothing -> pure Nothing
               Just x ->
                 case x of
                   Left err -> fail err
                   Right pi -> pure $ Just pi
  Louse fp prjInfo <$> readBugsFromErr fp <*> readPeopleFromErr fp

-- |Lazily reads the bugs.
readBugsFromErr 
  :: FilePath             -- ^The path to the project directory
  -> IO (M.Map BugId Bug) -- ^The resulting Map
readBugsFromErr fp = 
  readFilesFromErr $ mappend fp _bugs_dir

-- |Lazily reads the bugs.
readPeopleFromErr 
  :: FilePath          -- ^The path to the project directory
  -> IO (M.Map PersonId Person) -- ^The resulting Map
readPeopleFromErr fp = 
  readFilesFromErr $ mappend fp _people_dir

-- |Lazily reads files in a directory, returns a 'M.Map' of the name
-- of the file, along with the decoded value.
readFilesFromErr 
  :: FromJSON t 
  => FilePath     -- ^The directory holding the files
  -> IO (IdMap t) -- ^The resulting Map
readFilesFromErr directoryPath = do
  fs <- drop 2 <$> files
  mconcat <$> mapM mkMapMember fs
  where
    files :: IO [FilePath]
    files = getDirectoryContents directoryPath

    -- This function constructs an individual element of the Map
    mkMapMember :: FromJSON t => FilePath -> IO (IdMap t)
    mkMapMember filePath = do
      fexists <- doesFileExist filePath
      if | fexists -> pure M.empty
         | otherwise -> do
            fcontents <- Bl.readFile filePath
            decodedValue <- case eitherDecode fcontents of
                              Left err -> fail err
                              Right x  -> pure x
            pure $ M.singleton (T.pack (deCanonicalize filePath)) decodedValue
    -- quux.yaml -> quux
    removeDot :: FilePath -> FilePath
    removeDot = reverse . drop 5 . reverse

    -- Split a string on "/"
    splitSlashes :: FilePath -> [FilePath]
    splitSlashes fp = split "/" fp

    -- Takes a canonical filename: /foo/bar/baz/quux.yaml -> quux . Also converts to Text while it's at
    -- it.
    deCanonicalize :: FilePath -> FilePath
    deCanonicalize fp =
      case removeDot <$> lastMay (splitSlashes fp) of
        Just x  -> x
        Nothing -> fp

-- |Look up a bug by its 'BugId'
lookupBug :: Louse -> BugId -> Maybe Bug
lookupBug louse bugid = M.lookup bugid $ louseBugs louse

-- |Look up a person by their 'PersonId'
lookupPerson :: Louse -> PersonId -> Maybe Person
lookupPerson louse personid = M.lookup personid $ lousePeople louse

-- |Get the status
statusStr :: FilePath -> IO String
statusStr dir = do
  let errprint = hPutStrLn stderr
  louse <- tryIOError (readLouseFromErr dir)
           >>= \case
             Left err
               | isDoesNotExistError err -> do
                   errprint $ "Oops! You don't appear to have a louse repository in " <> dir
                   errprint "Hint: Try running `louse init`."
                   exitFailure
               | isPermissionError err -> do
                   errprint $ "I got a permission error when trying to read the louse repo in " <> dir
                   errprint "Do you have permission to read this directory?"
                   exitFailure
               | isAlreadyInUseError err -> do
                   errprint $ "Another process is using the louse repo in " <> dir
                   errprint "I don't know what to do about that, so I'm just going to quit."
                   exitFailure
               | otherwise -> ioError err
             Right l -> pure l

  let bugs = louseBugs louse
      nTotalBugs = M.size bugs
      nOpenBugs = length $ M.filter bugOpen bugs
      closureRate = (`mappend` "%") . show . round . (* 100) $ nOpenBugs % nTotalBugs
  pure $ unlines
           [ "Louse directory: " <> dir
           , "Open bugs: " <> show nOpenBugs
           , "Closure rate: " <> closureRate
           ]
