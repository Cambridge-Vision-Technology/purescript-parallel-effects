module Control.Monad.BatchRun.FileSystem
  ( FileSystemF(..)
  , FILE_SYSTEM
  , _filesystem
  , readFile
  , writeFile
  , deleteFile
  , fileExists
  , runFileSystem
  , runFileSystemAt
  ) where

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.BatchRun as Control.Monad.BatchRun
import Control.Parallel as Control.Parallel
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect.Aff as Effect.Aff
import Node.Encoding as Node.Encoding
import Node.FS.Aff as Node.FS.Aff
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

-- | FILE_SYSTEM effect row type
-- | Example: BatchRun (FILE_SYSTEM (LOGGING r)) Unit
type FILE_SYSTEM r = (filesystem :: FileSystemF | r)

data FileSystemF a
  = ReadFile String (String -> a)
  | WriteFile String String (Unit -> a)
  | DeleteFile String (Unit -> a)
  | FileExists String (Boolean -> a)

derive instance Functor FileSystemF

_filesystem :: Type.Proxy.Proxy "filesystem"
_filesystem = Type.Proxy.Proxy

-- | Read file contents
readFile :: forall r. String -> Control.Monad.BatchRun.BatchRun (FILE_SYSTEM r) String
readFile path = Control.Monad.BatchRun.lift _filesystem (ReadFile path identity)

-- | Write file contents
writeFile :: forall r. String -> String -> Control.Monad.BatchRun.BatchRun (FILE_SYSTEM r) Unit
writeFile path contents = Control.Monad.BatchRun.lift _filesystem (WriteFile path contents identity)

-- | Delete a file
deleteFile :: forall r. String -> Control.Monad.BatchRun.BatchRun (FILE_SYSTEM r) Unit
deleteFile path = Control.Monad.BatchRun.lift _filesystem (DeleteFile path identity)

-- | Check if file exists
fileExists :: forall r. String -> Control.Monad.BatchRun.BatchRun (FILE_SYSTEM r) Boolean
fileExists path = Control.Monad.BatchRun.lift _filesystem (FileExists path identity)

-- | Handle FILE_SYSTEM effects for programs with only FILE_SYSTEM (no other effects)
runFileSystem :: forall a. Control.Monad.BatchRun.BatchRun (FILE_SYSTEM ()) a -> Effect.Aff.Aff a
runFileSystem = runFileSystemAt _filesystem Control.Monad.BatchRun.impossibleVariant

-- | Handle FILE_SYSTEM effects at a specific label
runFileSystemAt
  :: forall sym q r a
   . IsSymbol sym
  => Prim.Row.Cons sym FileSystemF q r
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF q x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun r a
  -> Effect.Aff.Aff a
runFileSystemAt sym handler prog =
  Control.Monad.BatchRun.runParallel (\v -> Control.Monad.BatchRun.on sym handleFileSystem handler v) prog
  where
  handleFileSystem :: FileSystemF ~> Effect.Aff.Aff
  handleFileSystem (ReadFile path cont) = do
    contents <- Node.FS.Aff.readTextFile Node.Encoding.UTF8 path
    pure $ cont contents

  handleFileSystem (WriteFile path contents cont) = do
    Node.FS.Aff.writeTextFile Node.Encoding.UTF8 path contents
    pure $ cont unit

  handleFileSystem (DeleteFile path cont) = do
    Node.FS.Aff.unlink path
    pure $ cont unit

  handleFileSystem (FileExists path cont) = do
    result <- Effect.Aff.attempt $ Node.FS.Aff.stat path
    pure $ cont $ Data.Either.either (const false) (const true) result
