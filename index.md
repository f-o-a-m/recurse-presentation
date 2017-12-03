build-lists: true
autoscale: true

# Introduction to purescript-web3
### Martin Allen, FOAM

---

# TOC

* ethereum
* purescript
* purescript-web3

---

# ethereum

- second most popupular blockchain and cryptocurrency
- turing-complete[^0] statemachine (EVM)
- allows consensus around execution of smart contracts

[^0]: Gas solves the non-termination problem

---

![100%](images/txs.png)

source: etherscan.io as of 12/2/2017

---

![100%](images/addresses.png)

source: etherscan.io as of 12/2/2017

---

![100%](images/marketcap.png)

source: etherscan.io as of 12/2/2017

---

# solidity

- javascript like syntax
- special blockchain, crypto and signature-recovery primitives
- types for EVM primitives such as `uint48`
- interface through `ABI`

---

```javascript
contract GreedyStorage is owned {

  uint public m; // automatically generate getM()
  
  function increase (uint n) onlyOwner returns (uint) 
  {
     m = m + n;
     return m;
  }
  
  function override (uint n) payable 
  {
    require(msg.value > 100000);  // this is the price
    m = n;
    log0(bytes32(msg.sender));
  }
  
}
```

[edit on remix](https://ethereum.github.io/browser-solidity/#version=soljson-v0.4.19+commit.c4cbbb05.js&optimize=undefined&gist=a90b20b6df66c98f7af2f912952d2b7d)

---

```haskell
abi :: FunctionSignature -> ByteString
abi = take 8 $ sha3

> abi "increase(uint256)"
> "30f3f0db"
```

so for `GreedyStorage` we get

```json
{
    "30f3f0db": "increase(uint256)",
    "5a2ee019": "m()",
    "94d9e61c": "override(uint256)"
}
```

---

# typesafety (on-chain)
- work underway for strongly typed languages targeting EVM
- typesafe EVM language wouldn't necessarily have prevented infamous bugs. We'd need session types or similar.
- fundamental problem is `call()`-out from turingcomplete executable to turingcomplete executable. Types are not preserved on EVM.

---

# typesafety (off-chain)
- prevent catastrophes for
  - encoding errors

---

> The token sale kicked off on schedule at 4:00pm UTC. About 20 minutes in, we realized something was awry with the contract transfer address. Whilst generating the contract bytes for deployment, a mistake was made defining the constructor parameters. Instead of a quoted string for an address, a Javascript hex string was used, i.e: “0x03e4B00B607d09811b0Fa61Cf636a6460861939F”
This resulted in an address in the byte code that looked very much like the actual address, but was not, i.e: “0x3e4b00b607d0980668ca6e50201576b00000000.” This address was incorrectly verified before deployment due to its similarities.

REX token sale (7/31/2017)

---

![100%](images/rex.png)

---

# typesafety (off-chain)
- prevent catastrophes for
  - encoding errors
  - migrations

---

```javascript
contract A {
  uint n;
  function A (uint _arg) {
    n = _arg;
  }
}
```

---
```javascript
contract A {
  int n;
  function A (int _arg) {
    n = _arg;
  }
}
```

---


---

# typesafety (off-chain)
- prevent catastrophes for
  - encoding errors
  - migrations
- convenience
  - CD
  - compile time errors

---
build-lists: true
autoscale: true

# Introduction to purescript-web3
### Martin Allen, FOAM

---

# TOC

* ethereum
* purescript
* purescript-web3

---

## a haskell programmer's solution to the javascript problem

- product, coproduct (sum) and record-types
- GADTs, prism/lens/traversals
- RowTypes...

```haskell
data MyProd = MyProd Int String

data MySum = MyInt Int 
           | MyString String

data MyRec1 = MyRec1 {name :: String, size :: Int}
data MyRec2 = MyRec2 {age :: Int, nice :: Boolean}

data MyRecProd = MyRecProd MyRec1 MyRec2

data MyRecSum  = FirstRec MyRec1 
               | SndRec MyRec2
```

---

## a haskell programmer's solution to the javascript problem

- compiles to clean JS code
- doesn't yet optimize
- easy FFI

---

# Comparison with
- elm
- ghcjs

---

build-lists: true
autoscale: true

# Introduction to purescript-web3
### Martin Allen, FOAM

---

# TOC

* ethereum
* purescript
* purescript-web3

---

# purescript-web3


# Library Layout

1. Low level serialization and RPC layer
- Solidity types
- (de)serialization
- web3 api 
2. User Interface and Generator Tool
- `Contract` module
- Methods and Events
- purescript-web3 generator

---

# Solidity Types

## Sized Types
- Purescript does not as of yet have type level naturals
- Luckily we don't need infinitely many
- `Network.Ethereum.Web3.Solidity.Size`
- `D0` ... `D9` and `(:&) :: Type -> Type -> Type`
- `Z :: Type`, `S :: Type -> Type`
- `class KnownSize s`, `class KnownNat n`
- `class KnownSize n <= ByteSize n`
- `class KnownSize n <= IntSize n`


---

### Sized Ints

```haskell
newtype UIntN n = UIntN BigNumber

uIntNFromBigNumber :: 
  forall n . 
     KnownSize n 
  => BigNumber 
  -> Maybe (UIntN n)

type UInt = UIntN (D2 :& D5 :& D6)
```

---

### Vectors

- Purescript makes it pretty easy to implement length indexed vectors

```haskell
newtype Vector n a = Vector (Array a)

nilVector :: forall a . Vector Z a
nilVector = Vector mempty

vCons :: 
  forall a n . 
     a 
  -> Vector n a 
  -> Vector (S n) a
vCons a (Vector as) = Vector (a : as)

toVector :: 
  forall a n . 
     KnownNat n 
  => Array a 
  -> Maybe (Vector n a)

```

---

### Tuples
- The EVM is a stack based virtual machine with a maximum depth of 16. Not very impressive, but limits the possible tuple sizes.
```haskell

data Tuple0 = Tuple0

newtype Tuple1 a = Tuple1 a

...

data Tuple16 a b c d e f g h i j k l m n o p = 
  Tuple16 a b c d e f g h i j k l m n o p

```
- First iteration of `purescript-web3` didn't handle these well.

---

## Basic (De)Serialization
- All basic Solidity types implement the following type classes for the ABI encoding schema.

```haskell
class ABIEncode a where
  toDataBuilder :: a -> HexString

class ABIDecode a where
  fromDataParser :: Parser String a
```

```haskell
instance abiEncodeUint :: IntSize n => ABIEncode (UIntN n) where
  toDataBuilder a = uInt256HexBuilder <<< unUIntN $ a

instance abiDecodeUint :: IntSize n => ABIDecode (UIntN n) where
  fromDataParser = do
    a <- uInt256HexParser
    maybe (fail $ msg a) pure <<< uIntNFromBigNumber $ a
    where
      msg n = let size = sizeVal (Proxy :: Proxy n)
              in "Couldn't parse as uint" <> show size <> " : " <> show n

```

---

## Tuples
- All Solidity functions accept and return tuples
- Events are emitted as tuples, though not as straight forward to handle
- Encoding and Decoding implemented "generically"


---
## Generics Primer (Advanced)
- All "basic" purescript types (i.e. of kind `Type`) admit a generic decomposition
```haskell
data Argument a = Argument a
data Product a b = Product a b
data Constructor (s :: Symbol) a = Constructor a

from (Tuple3 Bool String (UInt D8)) ::
  Constructor "Tuple3" (Product (Argument Bool) (Product (Argument String) (Argument UInt D8))) 

```
- Compiler implements generic decompositions for us, so we can use them for free.
- We can inductively build up generic types to have a certain property, such as `ABIEncode`
```haskell
instance genericEncodeBase :: ABIEncode a => GenericABIEncode (Argument a)
instance genericEncodeInductive :: (ABIEncode a, GenericABIEncode b) => GenericABIEncode (Product (Argument a) b)
```
---

## Generics

- enables extremely local reasoning, building up more complicated expressions from smaller ones whose correctness is easier to prove.
- "generics" code is extremely reusable.

```haskell
genericEncode ::
  forall a rep .
     Generic a rep
  => GenericABIEncode rep
  => a
  -> HexString
genericABIEncode = genericToDataBuilder <<< from

```
---

## Web3 API

- The Web3 API is a set of RPC methods that the ethereum client knows about
- There are a lot, the type signatures can serve as a sort of documentation

```haskell
eth_sendTransaction :: 
  forall p e . 
     IsAsyncProvider p 
  => TransactionOptions 
  -> Web3 p e HexString

eth_newFilter ::
  forall p e . 
     IsAsyncProvider p 
  => Filter 
  -> Web3 p e FilterId


eth_getFilterChanges :: 
  forall p e . 
     IsAsyncProvider p 
  => FilterId 
  -> Web3 p e (Array Change)

...

```

---

## Web3 API

- Implementation of the client portion heavily inspired by the hs-web3 implementation.
- How easy is it to add new endpoints as they are released?
```haskell
eth_sendTransaction :: forall p e . IsAsyncProvider p => TransactionOptions -> Web3 p e HexString
eth_sendTransaction opts = unsafeCoerceWeb3 $ remote "eth_sendTransaction" opts :: Web3 p () HexString
```
- Pretty easy!

---
## User Interface

You will be able to use `purescript-web3` without knowing how it works. This means:
 
 1. Calling contract methods, listening for events, querying blockchain metadata, full web3 api implementation.
 2. Interacting with metamask.
 3. Easily generate a small client library for every contract.

---

## Generator -- Simple Storage

Simple Storage allows us to change a `uint256`, query that state, and listen for updates to that state.

```solidity
contract SimpleStorage {
    uint public count;

    event CountSet(uint _count);

    function setCount(uint _count) {
        count = _count;
        CountSet(_count);
    }
}

```
---
## Generator -- Simple Storage

Here is the client library generated which is generated from the ABI [^1]

```haskell
count ::
  forall e p . 
     IsAsyncProvider p 
  => Address 
  -> Maybe Address 
  -> CallMode 
  -> Web3 p e (UIntN (D2 :& D5 :& D6))

setCount :: 
  forall e p . 
     IsAsyncProvider p 
  => Maybe Address 
  -> Address 
  -> UIntN (D2 :& D5 :& D6) 
  -> Web3 p e HexString

newtype CountSet = 
  CountSet { _count :: UIntN (D2 :& D5 :& D6) }

```
[^1]: There are a few other boiler plate type declarations, but this is pretty much it.

--- 

## Benefits of the generator approach

1. You don't want to access the raw encoders/decoders manually when templating your transactions, laborious and potentially error prone.
2. The generator is meant to be run as an npm step, meaning that if you change your contracts 

---

# Function Application

```haskell
> john Eggs

Unhappy
```

```haskell
> john Coffee

Happy
```
---
# The Real Deal

1. **Totality**. Every element in *domain* must be mapped to some element in *codomain*.
2. **Determinism**. Applying a function with the same value (in domain) results in same value (in codomain).

---

# Exercise Set 1

```haskell
data CharacterStatus = Content | Hungry | Tired

describeCharacterStatus :: CharacterStatus -> String
```

1. Create a set called `CharacterStatus`, which represents the different states of the player.
2. Create a function called `describeCharacterStatus` which describes the state of the player.

---

# Types
### Sets of values.

---

# Literal Types

 * `String`  : The set that contains all strings; `"foo"` is an element of this set.
 * `Number`  : The set that contains all numbers;[^0] `5.5` is an element of this set.
 * `Int`     : The set that contains all integers; `3` is an element of this set.
 * `Char`    : The set that contains all characters; `'J'` is an element of this set.
 * `Boolean` : The set that contains the values `true` and `false`.

Plus records `{foo: "bar"}` and arrays `[1, 2, 3]`!

[^0]: Not really, $%#@&!!

---

# Product Types[^1]

```haskell
data Loc = Loc Int Int
```

[^1]: They get their name from an easy way you can use to compute the size of these sets (hint: product = multiplication).

---

# Product Types

```haskell
  data Loc = Loc Int Int
--      |
--      |
--      |
--  The name of
--   the type.   
```

---

# Product Types

```haskell
  data Loc = Loc Int Int
--         |
--         |
--         |
-- Nonsense, please ignore!
```

---

# Product Types

```haskell
  data Loc = Loc Int int
--            |
--            |
--            |            
-- The name of a function
-- that will create values
-- of the type. AKA the
--     constructor!
```

---

# Product Types

```haskell
  data Loc = Loc Int Int
--                 \  /
--                  \/
--     Constructor parameters (types).
```

---

# Product Types

```haskell
data Loc = Loc Int Int

whereAmI = Loc 1 2
```

---

# Product Types
### What's the opposite of *con*struction?[^4]

```haskell
locX :: Loc -> Int
locX (Loc x _) = x

locY :: Loc -> Int
locY (Loc _ y) = y

locX (Loc 1 2) -- 1
locY (Loc 1 2) -- 2
```

[^4]: *De*construction, of course! AKA *pattern matching*.

---

# Product Types
### Another way to deconstruct.

```haskell
locX :: Loc -> Int
locX l = case l of
           (Loc x _) -> x
```

---

# Exercise Set 2

```haskell
data CharacterStats = CharacterStats Int Int

startingStats :: CharacterStats

healthOf :: CharacterStats -> Int

strengthOf :: CharacterStats -> Int
```

1. Create a `CharacterStats` product type to model some character statistics in an role-playing game (e.g. health and strength.).
2. Create some values of that type to understand how to use data constructors (`startingStats`).
3. Use pattern matching to extract individual components out of the data type (`healthOf`, `strengthOf`).

---

# Coproduct Types
### (AKA 'Sum' Types)[^2]

```haskell
data NPC =
  Ogre String Loc Int |
  Wolf String Loc Int
```

[^2]: They get their name from an easy way you can use to compute the size of these sets (hint: sum = addition).

---

# Coproduct Types

```haskell
-- The name of
--  the type
--     |
--     |
  data NPC =
    Ogre String Loc Int |
    Wolf String Loc Int
```

---

# Coproduct Types

```haskell
  data NPC =
    Ogre String Loc Int |
    Wolf String Loc Int
--   |
--   |
-- Data constructor.  
```
---

# Coproduct Types

```haskell
  data NPC =
    Ogre String Loc Int |
    Wolf String Loc Int
--          |    |    |
--           \   |   /
--             \ | /
--   Constructor parameters (types).
```
---

# Coproduct Types
### Destruction / pattern matching.

```haskell
nameOf :: NPC -> String
nameOf (Ogre name _ _) = name
nameOf (Wolf name _ _) = name
```
---

# Coproduct Types
### Deconstruction / pattern matching.

```haskell
data NPC =
  Ogre String Loc Int |
  Wolf String Loc Int

nameOf :: NPC -> String
nameOf npc = case npc of
               (Ogre name _ _) -> name
               (Wolf name _ _) -> name
```

---

# Exercise Set 3

```haskell
data Monster
  = Wolf CharacterStats
  | Ogre CharacterStats

bigBadWolf :: CharacterStats

fearfulOgre :: CharacterStats

monsterStrength :: Monster -> Int
```

1. Create a `Monster` sum type to represent different types of monsters in a game. Make sure they share at least one common piece of information (e.g. `health` or `name`).
2. Create a few monsters of varying types (`bigBadWolf`, `fearfulOgre`).
3. Create a function to extract out a piece of information common to all constructors (`monsterStrength`).

---

# Record Types[^5]

```haskell
data NPC =
  Ogre {name :: String, loc :: Loc, health :: Int} |
  Wolf {name :: String, loc :: Loc, health :: Int}
```

[^5]: Record types are represented using native Javascript objects.

---
# Record Types

```haskell
  data NPC =
    Ogre {name :: String, loc :: Loc, health :: Int} |
    Wolf {name :: String, loc :: Loc, health :: Int}
--       |                                         |
--       \--------------------|--------------------/
--                            |
--                       Record type.
```

---

# Record Types

```haskell
  data NPC =
    Ogre {name :: String, loc :: Loc, health :: Int} |
    Wolf {name :: String, loc :: Loc, health :: Int}
--        |                                       |
--        \-------------------|-------------------/
--                            |
--                    A 'row' of types.
```

---

# Record Types

```haskell
  data NPC =
    Ogre {name :: String, loc :: Loc, health :: Int} |
    Wolf {name :: String, loc :: Loc, health :: Int}
--         |
--      A label.
```

---

# Record Types

```haskell
  data NPC =
    Ogre {name :: String, loc :: Loc, health :: Int} |
    Wolf {name :: String, loc :: Loc, health :: Int}
--                  |
--        The type of the label.
```

---

# Record Types
### Construction / deconstruction.

```haskell
makeWolf :: String -> Loc -> Int -> NPC
makeWolf name loc health = Wolf {name: name, loc: loc, health: health}

nameOf :: NPC -> String
nameOf (Ogre { name : n }) = n
nameOf (Wolf { name : n }) = n
```

---

# Record Types
### The dot operator.

```haskell
nameOf :: NPC -> String
nameOf (Ogre record) = record.name
nameOf (Wolf record) = record.name
```

---

# Record Types
### 'Updating' records.

```haskell
changeName :: NPC -> NPC
changeName (Ogre r) = Ogre r { name = "Shrek" }
changeName (Wolf r) = Wolf r { name = "Big Bad" }
```

---

# Record Types
### Magic record syntax stuff.

```haskell
(_ { name = "Shrek" }) // Function from record to updated record

record { name = _ }    // Function from string to updated `record`

(_ { name = _ })       // Guess? :-)

```

---

# Exercise Set 4

```haskell
type State = {
  playerStatus :: CharacterStatus,
  playerStats  :: CharacterStats }
```

1. Modify the `State` record in `Game.State` to add `playerStatus` and `playerStats` (you will have to modify `initial` in the `Main` module).
2. Modify the `describe` function in `Main` so it describes the player state.

---

# Basic Function Types

```haskell
data Monster = Giant | Alien
data FavoriteFood = Humans | Kittens

fave :: Monster -> FavoriteFood
fave Giant = Humans
fave Alien = Kittens
```

---

# Basic Function Types
### Lambdas AKA closures AKA anonymous functions AKA arrow functions AKA...

```haskell
fave :: Monster -> FavoriteFood
fave = \monster -> case monster of
  Giant -> Humans
  Alien -> Kittens
```

```javascript
var fave = function(monster) {
  ...
}
```

```javascript
// ECMAScript 6
var fave = monster => ...
```

---

# Exercise Set 5

1. Describe the type of a function called `defeats`, which determines if a first `CharacterStats` can be used to defeat a second `CharacterStats` (by returning `true` or `false`).
2. Implement the function by using a lambda (hint: `defeats = \stats1 stats2 -> ...` or `defeats = \stats1 -> \stats2 -> ...`).

---

# Type Aliases
### What's in a name?

```haskell
type CharData =
  {name :: String, loc :: Loc, health :: Int}

data NPC = Ogre CharData | Wolf CharData
```

---

# Newtypes
### Wrappers without the overhead.


```haskell
newtype Health = Health Int

dead :: Health
dead = Health 0
```

---

# Newtypes
### Deconstruction / pattern matching.

```haskell
newtype Health = Health Int

isAlive :: Health -> Boolean
isAlive (Health v) = v > 0

isAlive h = case h of
              Health v -> v > 0
```

---

# Exercise Set 6

1. Create newtypes for any numeric statistics in `CharacterStats` (e.g. `Health` and `Strength`).
2. Create a type synonym called `StatsModifier` for a function `CharacterStats -> CharacterStats`.

---

# Higher-Order Functions
### Or, OMG sets can hold functions!!!

---

# Higher-Order Functions
### Functions that accept functions.

```haskell
likesEmptyString :: (String -> Boolean) -> Boolean
likesEmptyString f = f ""
```

---

# Higher-Order Functions
### Functions that return functions.

```haskell
matches :: String -> (String -> Boolean)
matches v = \text -> text == v

matchesEvil = matches "evil"

matchesEvil "john" -- false
matchesEvil "evil" -- true
```

---

# Higher-Order Functions
### "Multi-parameter" functions.[^6]

```haskell
damageNpc :: Int -> (NPC -> NPC)
damageNpc damage = \npc -> ...
```

[^6]: Not *really*, of course: functions in PureScript are always functions *from* one set *to* another set.

---


# Higher-Order Functions
### Making sense of "multi-parameter" functions: values.

```haskell
f a b c d e

-- (((((f a) b) c) d) e)
```

---


# Higher-Order Functions
### Making sense of "multi-parameter" functions: types.

```haskell
f :: a -> b -> c -> d -> e

-- f :: (a -> (b -> (c -> (d -> e))))
```


---

# Higher-Order Functions
### MORE functions that return functions.

```haskell
damageNpc :: Int -> (NPC -> NPC)
damageNpc = \damage -> \npc -> ...
```

```haskell
damageNpc :: Int -> (NPC -> NPC)
damageNpc = \damage npc -> ...
```

```haskell
damageNpc :: Int -> (NPC -> NPC)
damageNpc damage = \npc -> ...
```

```haskell
damageNpc :: Int -> (NPC -> NPC)
damageNpc damage npc = ...
```

---

# Exercise Set 7

```haskell
boostHealth :: Int -> (CharacterStats -> CharacterStats)

boostStrength :: Int -> (CharacterStats -> CharacterStats)
```

1. Create a function `boostHealth`  which, given an integer amount, returns another function that takes stats and boosts their health.
2. Create a function `boostStrength`  which, given an integer amount, returns another function that takes stats and boosts their health.

---

# Parametric Polymorphism
### Para..what?

---

# Polymorphic Data
### Type constructors: data with "holes".

```haskell
data Map4x4 a =
  Map4x4 a a a a
         a a a a
         a a a a
         a a a a

boolMap4x4 :: Map4x4 Boolean =
  Map4x4 true  true  false true
         false true  true  true
         false false false true
         true  false false true
```

---

# Polymorphic Data
### Type-level functions.

```haskell

-- invalid :: Map4x4  <- Not a type; a type function!

valid :: Map4x4 Boolean
```

## The type constructor `Map4x4` is a *function* whose domain is the set of all types. Pass it a type, and it will return a type!

---

# Polymorphic Functions
### Or, OMG sets can hold sets!!!

---

# Polymorphic Functions
### The heart of functional abstraction.

```haskell
upperLeft :: forall a. Map4x4 a -> a
upperLeft v _ _ _
          _ _ _ _
          _ _ _ _
          _ _ _ _ = v
```

---

# Polymorphic Functions
### How to read these crazy signatures.

```haskell
upperLeft :: forall a. Map4x4 a -> a

-- (a :: Type) -> Map4x4 a -> a
```

---

# Exercise Set 8

```haskell
data Inventory a b
  = LeftHand a
  | RightHand b
  | BothHands a b
  | Empty

isEmpty :: ???
```

1. Create a polymorphic `Inventory` sum type that can represents what the player is carrying in his or her hands.
2. Create a polymorphic function that determines whether or not the player is carrying anything.

---

# Extensible Rows
### Like duck typing only better.

```haskell
type Point r = { x :: Int, y :: Int | r }
```

---

# Extensible Rows
### Like duck typing only better.

```haskell
type Point r = { x :: Int, y :: Int | r }
--         |                        |
--         |                        |
--    'remainder'     syntax that means "the rest of the row"

gimmeX :: forall r. Point r -> Int
gimmeX p = p.x

gimmeX {x: 1, y: 2, z: 3} -- 1 - works!

-- gimmeX {x: 1, z: 3}    -- Invalid, no y!
```

---

# Exercise Set 9

```haskell
type NonPlayerCharacter = ???
type Item = ???
type PlayerCharacter = ???

getName :: ???
getName r = r.name
```

1. Create records for `NonPlayerCharacter`, `Item`, and `PlayerCharacter` that all share at least one field (`name`).
2. Create a function that extracts a name from any record which has *at least* a `name` field of type `String`.

---

# Kinds
### Categories of sets.

---

# `*`

### The name for the category of *sets of values*.
### (AKA *Type*)

Includes things like:

 * `CharacterStatus`
 * `CharacterStats`
 * `String`

---

# `* -> *`
### The name for the category of *type-level functions*.
### (AKA Higher-Kinded Type / Type Constructor)

---

# `* -> *`

```haskell
data List a = Nil | Cons a (List a)
```

---

# `* -> *`
### Type constructors are just (math) functions!


```haskell
addOne :: Int -> Int
addOne n = n + 1

result = addOne 1

List :: * -> *
data List a = Nil | Cons a (List a)

Result = List Int
```

---

# `* -> * -> *`
### Turtles all the way down.

```
Map :: * -> * -> *
data Map k v = ...
```


---
# `(* -> *) -> *`
### More turtles.

```haskell
Container :: (* -> *) -> *
data Container f = {create :: forall a. a -> f a}

list :: Container List
list = Container {create: \a -> Cons a Nil}
```

---

# `* -> * -> * -> * -> * -> *`
### Reading type constructors.

```haskell
foo :: f a b c d e

-- (((((f a) b) c) d) e)
```

---

# `Effect`
### The name for the category of *sets of effects*.

```haskell
foreign import data DOM :: Effect
```

---

# `# Effect`
### The name for the category of *rows of effects*.

```haskell
-- Supply a row of effects and a type,
-- and get back another type:
foreign import data Eff :: # Effect -> * -> *

trace :: forall r. String -> Eff (trace :: Trace | r) Unit
```

---

# `# *`
### The name for the category of *rows of types*.

```haskell
-- Supply a row of types, get back another type:
foreign import data Object :: # * -> *
```

---

# Foreign Types[^7]

```haskell
foreign import data jQuery :: *
```

[^7]: THERE BE DRAGONZ HERE!!!

---

# FP Toolbox
### Stuff you couldn't escape even if you wanted to.

---

# FP Toolbox
### Maybe it's there, maybe it's not?[^8]

```haskell
data Maybe a = Nothing | Just a

type Player =
  { armour :: Maybe Armor }
```

[^8]: AKA `null`, the FP way.

---

# FP Toolbox
### List: the ultimate FP data structure.

```haskell
data List a = Nil | Cons a (List a)
--                       |    |
--                     head   |
--                          tail

oneTwoThree = Cons 1 (Cons 2 (Cons 3 Nil))
```

---

# FP Toolbox
### `Either` it's this or it's that.

```haskell
data Either a b = Left a | Right b

type Player =
  { rightHand :: Either Weapon Shield }
```

---

# FP Toolbox
### `Tuple`, the opposite of `Either`.[^9]

```haskell
data Tuple a b = Tuple a b
--                     | |
--                 first second
I
type Player =
  { wrists :: Tuple (Maybe Bracelet) (Maybe Bracelet) }
```

[^9]: AKA sometimes it's just too damn hard to name stuff!

---

# FP Toolbox
### Native Javascript arrays.

```haskell
[1, 2, 3] :: Array Int
```

---

# Exercise Set 10

```haskell
import Data.List(List(..))

data Location
  = OutideCave
  | InsideCave
  | Plains

data Connection
  = GoNorth Location Location
  | GoSouth Location Location
  | GoEast Location Location
  | GoWest Location Location

northsouth :: Location -> Location -> List Connection
northsouth n s = Cons (GoNorth s n) (Cons (GoSouth n s) Nil)

westeast :: Location -> Location -> List Connection
westeast w e = Cons (GoWest e w) (Cons (GoEast w e) Nil)

--
--  OutsideCave -- Plains
--       |
--       |
--   InsideCave
--
gameMap :: List Connection
gameMap =
  northsouth OutsideCave InsideCave ++
  westeast OutsideCave Plains
```

1. Define a `Location` data type to represent all possible locations in the game world.
2. Define a `Connection` data type to represent a connection (or passageway) from one location to another.
3. Create a hypothetical `gameMap` (which has type `List Connection`), representing the geography of the game world.

---

# Type Classes
### Generic interfaces, the FP way.

---

# Type Classes
### Generic interfaces in Java.

```java
public interface Appendable<A> {
  public A append(A a1, A a2);
}
class AppendableInt implements Appendable<Integer> {
  public Integer append(Integer a1, Integer a2) {
    return a1 + a2;
  }
}
Appendable<Integer> appendableInt = new AppendableInt();
appendableInt.append(1, 2); // 3!
```

---

# Type Classes
### Generic 'interfaces' in Javascript.

```javascript
function makeAppendable(append) {
  return {
    append: append
  };
}

var boolAppendable = makeAppendable(
  function(v1, v2) {
    return v1 && v2;
  }
);

boolAppendable.append(true, false); // false!
```

---

# Type Classes
### Generic interfaces in PureScript.

```haskell
class Appendable a where
  append :: a -> a -> a

instance appendableInt :: Appendable Int where
  append a1 a2 = a1 + a2

append 1 2 -- 3!
```

---

# Type Classes
### Turbocharged polymorphism.

```haskell
repeat :: forall a. (Appendable a) => Int -> a -> a
repeat 0 a = a
repeat n a = append (repeat (n - 1) a) a

sort :: forall a. (Ord a) => [a] -> [a]

-- etc.
```

---

# Type Classes
### Hierarchies: like OO inheritance, but not.

```haskell
class Eq a where
  equals :: a -> a -> Boolean

data Ordering = LT | GT | EQ

class (Eq a) <= Ord a where
  compare :: a -> a -> Ordering
```

---

# Type Classes
### Hierarchies: like OO inheritance, but not.

```haskell
class (Eq a) <= Ord a where
--       |
--       |
-- The superclass.
--
-- Read: "Ord a implies Eq a"
```

---

# Exercise Set 11

```haskell
class Describable a where
  describe :: a -> String

  examine :: a -> String

data Weapon = Sword | Spear

instance describableWeapon :: Describable Weapon where
  describe :: Weapon -> String

  examine :: Weapon -> String
```

1. Define a type class called `Describable` that can generate small and lengthy (`String`) descriptions of values of some type.
2. Create a `Weapon` data type to denote different types of weapons.
3. Create an instance of `Describable` for the `Weapon` data type.

---

# Effects
### Or, how to get in trouble *fast*.

---

```haskell
import Debug.Trace

main = trace "Hello World!"
```

---


```haskell
import Debug.Trace

main = do
  trace "Hello World!"

  trace "Bye World!"
```

---

# Exercise Set 12

1. Study the `Main` module to see how it uses effects to print out a description.

---

# Scary Sounding Things
### Monadic zygohistomorphic prepromorphisms...

## WTF?!?!!

---

# Scary Sounding Things
### Let's play a game: give your friend a birthday present that she'll adore.

---

# Scary Sounding Things
### The rules of the game.

**Rule 1**: If something is inside a box, you may change it to anything else and the result will still be inside the box.

**Rule 2**: If something is not inside a box, you can pack it into a box.

**Rule 3**: If something is packed inside a box which is packed inside another box, you can replace that with a single box containing that thing.

---

# Scary Sounding Things
### Your inventory.

**Item 1**: You have Ripley, a Chihuaha mutt who can magically change a lump of coal into a beautiful present that your friend will like.

**Item 2**: You have a box containing a box containing a lump of coal.

Which rules should you apply to create a birthday present your friend will adore???

---

# Scary Sounding Things
### The rules of the game, redux.

**Rule 1**: If something is inside a box, you may change it to anything else and the result will still be inside the box.
`(a -> b) -> f a -> f b`

**Rule 2**: If something is not inside a box, you can pack it into a box.
`a -> f a`

**Rule 3**: If something is packed inside a box which is packed inside another box, you can replace that with a single box containing that thing.
`f (f a) -> f a`

---

# Scary Sounding Things
### The rules of the game, redux redux.

```haskell
fmap :: (a -> b) -> f a -> f b -- AKA (<$>)

pure :: a -> f a               -- AKA return

join :: f (f a) -> f a

-- bind AKA (>>=) = \fa f -> join (fmap f fa)
```

---

# OMG a **monad**, run in terror!!!!!

---

# Nah, just kidding
## Scary sounding things give you **rewrite rules** you can use to **manipulate the types** into the form you require.

---

# The scary sounding names **don't matter** at all

---

# Exercise Set 13

```haskell
class Evitacilppa f where
  erup :: forall a. a -> f a

  pa :: forall a b. f (a -> b) -> f a -> f b
```

1. You are given `f Int` and `Int`, for some `Evitacilppa f`. If you have a function:

   `add :: Int -> Int -> Int`

   which "rewrite rules" do you need to use so that you can apply the `add` function to the two numbers?

---

# Let's Finish Our Game!
### Enough math already plz!!!

---

# The Soul of an RPG
### Or the types, anyway.

```haskell
type Game s i = {
  initial  :: s,
  describe :: s -> String,
  parse    :: String -> Either String i,
  update   :: s -> i -> Either String s }

runGame :: forall s i. Game s i -> Eff (game :: GAME) Unit
runGame g = ...
```

---

# On Your Marks, Get Set, Go!

---

# THANK YOU!
### John A. De Goes â€” @jdegoes
