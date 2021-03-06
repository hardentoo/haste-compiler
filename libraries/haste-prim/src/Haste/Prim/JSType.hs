{-# LANGUAGE MultiParamTypeClasses, ForeignFunctionInterface, MagicHash, 
             TypeSynonymInstances, FlexibleInstances, EmptyDataDecls,
             UnliftedFFITypes, UndecidableInstances, CPP, OverloadedStrings #-}
-- | Efficient conversions to and from JS native types.
module Haste.Prim.JSType (
    JSType (..), JSNum (..), toString, fromString, convert
  ) where
import GHC.Int
import GHC.Word
import Haste.Prim (JSString (..), toJSStr, fromJSStr)
#ifdef __HASTE__
import Haste.Prim (JSAny (..))
import GHC.Prim
import GHC.Integer.GMP.Internals
import GHC.Types (Int (..))
#else
import Data.Char
import GHC.Float
#endif

-- | Any type which can be converted to/from a 'JSString'.
class JSType a where
  toJSString   :: a -> JSString
  fromJSString :: JSString -> Maybe a

-- | (Almost) all numeric types can be efficiently converted to and from
--   Double, which is the internal representation for most of them.
class JSNum a where
  toNumber   :: a -> Double
  fromNumber :: Double -> a

instance JSType JSString where
  toJSString   = id
  fromJSString = Just

#ifdef __HASTE__

foreign import ccall "Number" jsNumber          :: JSString -> Double
foreign import ccall "String" jsString          :: Double -> JSString
foreign import ccall jsTrunc                    :: Double -> Int
foreign import ccall "I_toInt" jsIToInt         :: ByteArray# -> Int
foreign import ccall "I_toString" jsIToString   :: ByteArray# -> JSString
foreign import ccall "I_fromString" jsStringToI :: JSString -> ByteArray#
foreign import ccall "I_fromNumber" jsNumToI    :: ByteArray# -> ByteArray#

unsafeToJSString :: a -> JSString
unsafeToJSString = unsafeCoerce# jsString

unsafeIntFromJSString :: JSString -> Maybe Int
unsafeIntFromJSString s =
    case jsNumber s of
      d | isNaN d   -> Nothing
        | otherwise -> Just (unsafeCoerce# (jsTrunc d))


-- JSNum instances

instance JSNum Char where
  fromNumber = unsafeCoerce# jsTrunc
  toNumber = unsafeCoerce#

instance JSNum Int where
  fromNumber = unsafeCoerce# jsTrunc
  toNumber = unsafeCoerce#

instance JSNum Int8 where
  fromNumber n = case fromNumber n of I# n' -> I8# (narrow8Int# n')
  toNumber = unsafeCoerce#

instance JSNum Int16 where
  fromNumber n = case fromNumber n of I# n' -> I16# (narrow16Int# n')
  toNumber = unsafeCoerce#

instance JSNum Int32 where
  fromNumber = unsafeCoerce# jsTrunc
  toNumber = unsafeCoerce#

instance JSNum Word where
  fromNumber n =
    case jsTrunc (unsafeCoerce# n) of
      I# n' -> W# (int2Word# n')
  toNumber = unsafeCoerce#

instance JSNum Word8 where
  fromNumber w = case fromNumber w of W# w' -> W8# (narrow8Word# w')
  toNumber = unsafeCoerce#

instance JSNum Word16 where
  fromNumber w = case fromNumber w of W# w' -> W16# (narrow16Word# w')
  toNumber = unsafeCoerce#

instance JSNum Word32 where
  fromNumber w = case fromNumber w of W# w' -> W32# w'
  toNumber = unsafeCoerce#

instance JSNum Integer where
  toNumber (S# n) = toNumber (I# n)
  toNumber (J# n) = unsafeCoerce# (jsIToInt n)
  fromNumber n    = J# (jsNumToI (unsafeCoerce# n))

instance JSNum Float where
  fromNumber = unsafeCoerce#
  toNumber = unsafeCoerce#

instance JSNum Double where
  fromNumber = id
  toNumber = id

-- JSType instances
instance JSType Bool where
  toJSString True = "true"
  toJSString _    = "false"
  fromJSString "true"  = Just True
  fromJSString "false" = Just False
  fromJSString _       = Nothing
instance JSType Int where
  toJSString = unsafeToJSString
  fromJSString = unsafeIntFromJSString
instance JSType Int8 where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString
instance JSType Int16 where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString
instance JSType Int32 where
  toJSString = unsafeToJSString
  fromJSString = unsafeCoerce# unsafeIntFromJSString
instance JSType Word where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString
instance JSType Word8 where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString
instance JSType Word16 where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString
instance JSType Word32 where
  toJSString = unsafeToJSString
  fromJSString = fmap fromIntegral . unsafeIntFromJSString

instance JSType Float where
  fromJSString s =
    case jsNumber s of
      d | isNaN d   -> Nothing
        | otherwise -> Just (unsafeCoerce# d)
  toJSString = unsafeToJSString

instance JSType Double where
  fromJSString s =
    case jsNumber s of
      d | isNaN d   -> Nothing
        | otherwise -> Just d
  toJSString = unsafeToJSString

-- This is completely insane, but GHC for some reason pukes when we try to
-- use the constructors of the actual integers, so we coerce them into this
-- isomorphic type to work with them instead.
data Dummy = Small Int# | Big ByteArray#

instance JSType Integer where
  toJSString n =
    case unsafeCoerce# n of
      Small n' -> toJSString (I# n')
      Big n'   -> jsIToString n'
  fromJSString s =
    case jsStringToI s of
      n -> Just (unsafeCoerce# (Big n))

instance JSType String where
  toJSString     = toJSStr
  fromJSString   = Just . fromJSStr

instance JSType () where
  toJSString _ = toJSStr "()"
  fromJSString s | s == toJSStr "()" = Just ()
                 | otherwise = Nothing

#else

instance JSNum Char where
  toNumber = fromIntegral . ord
  fromNumber = chr . round

instance JSNum Int where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Int8 where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Int16 where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Int32 where
  toNumber = fromIntegral
  fromNumber = round

instance JSNum Word where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Word8 where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Word16 where
  toNumber = fromIntegral
  fromNumber = round
instance JSNum Word32 where
  toNumber = fromIntegral
  fromNumber = round

instance JSNum Double where
  toNumber = id
  fromNumber = id
instance JSNum Float where
  toNumber = float2Double
  fromNumber = double2Float

instance JSNum Integer where
  toNumber = fromInteger
  fromNumber = round

mread :: Read a => String -> Maybe a
mread s =
  case reads s of
    [(x, "")] -> x
    _         -> Nothing

instance JSType Int where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Int8 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Int16 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Int32 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType Word where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Word8 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Word16 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Word32 where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType Double where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr
instance JSType Float where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType Integer where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType Bool where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType () where
  toJSString = toJSStr . show
  fromJSString = mread . fromJSStr

instance JSType String where
  toJSString = toJSStr
  fromJSString = Just . fromJSStr

#endif

-- Derived functions

toString :: JSType a => a -> String
toString = fromJSStr . toJSString

fromString :: JSType a => String -> Maybe a
fromString = fromJSString . toJSStr

convert :: (JSNum a, JSNum b) => a -> b
convert = fromNumber . toNumber
