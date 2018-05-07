
module System.Mail.Notmuch.Utils where

import Foreign
import Foreign.C.String
import Data.Default
import System.Mail.Notmuch.Binding
import System.Mail.Notmuch.Wrapper
import System.Mail.Notmuch.Arrow

oneShotA :: (Database -> a -> IO b) -> NotmuchArrow s a b
oneShotA f = NmA (\db x b -> if b then f db x >>= \r -> return $ Right $ Just (r, False)
                                  else return $ Right Nothing
                 )
                 True

actPtr :: Default b => (Ptr a -> IO b) -> Ptr a -> IO b
actPtr f ptr = do
    if ptr == nullPtr then return def
                      else f ptr

dbStatusNmA :: NotmuchArrow s a String
dbStatusNmA = oneShotA dbStatusNm
dbStatusNm :: Database -> a -> IO String
dbStatusNm (Database cdb) _ = c_database_string cdb >>= actPtr peekCString

dbPathNmA :: NotmuchArrow s a FilePath
dbPathNmA = oneShotA dbPathNm
dbPathNm :: Database -> a -> IO FilePath
dbPathNm (Database cdb) _ = c_database_get_path cdb >>= actPtr peekCString

dbVersionNmA :: NotmuchArrow s a Integer
dbVersionNmA = oneShotA dbVersionNm
dbVersionNm :: Database -> a -> IO Integer
dbVersionNm (Database cdb) _ = toInteger <$> c_database_get_version cdb

makeAtomicNmA :: NotmuchArrow s a b -> NotmuchArrow s a b
makeAtomicNmA (NmA f init_acc) =
    NmA (\db x acc -> do
             let cdb = cData db
             stcode <- c_database_begin_atomic cdb
             if stcode /= success
             then return $ Left $ statusToErrorCode stcode
             else do r <- f db x acc
                     stcode' <- c_database_end_atomic cdb
                     if stcode' /= success
                     then return $ Left $ statusToErrorCode stcode'
                     else return r
        )
        init_acc

dbRevisionNmA :: NotmuchArrow s a (String,Integer)
dbRevisionNmA = oneShotA dbRevisionNm
dbRevisionNm :: Database -> a -> IO (String,Integer)
dbRevisionNm (Database cdb) _ =
    alloca $ \str_ptr -> do
    rev <- c_database_get_revision cdb str_ptr
    str <- peek str_ptr >>= actPtr peekCString
    return (str, toInteger rev)
