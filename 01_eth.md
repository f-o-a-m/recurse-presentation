# Introduction to purescript-web3

### Martin Allen, FOAM

---

# Plan of the talk

* Ethereum
* Purescript
* purescript-web3

---

## Ethereum
- Second most popupular blockchain and cryptocurrency
- Turing-complete[^0] statemachine (EVM)
- Allows consensus around execution of smart contracts

[^0]: What about gas?

---

![Ethereum transactions over time](images/txs.png)

source: etherscan.io as of 12/2/2017

---

![Unique transactions over time](images/addresses.png)

source: etherscan.io as of 12/2/2017

---

![Ethereum market cap over time](images/marketcap.png)

source: etherscan.io as of 12/2/2017

---

## Solidity
- Javascript like syntax
- Special blockchain, crypto and signature-recovery primitives
- Types for EVM primitives such as `uint48`
- Interface through `ABI`

---

```javascript
contract GreedyStorage is owned {
  
  uint public m; // automatically generate getM()
  
  event Overidden(address overrider)
  
  function increase (uint n) onlyOwner returns (uint) {
     m = m + n;
     return m;
  }
  
  function override (uint n) payable {
    require(msg.value > 100000);  // this is the price
    m = n;
    Overidden(msg.sender);
  }
}
```

[edit on remix](https://ethereum.github.io/browser-solidity/#version=soljson-v0.4.19+commit.c4cbbb05.js&optimize=undefined&gist=a90b20b6df66c98f7af2f912952d2b7d)

---

The **selector** is how we speficy the function to execute

```haskell
selector :: FunctionSignature -> ByteString
selector = take 8 $ sha3

> selector "increase(uint256)"
> "30f3f0db"
```

so for `GreedyStorage` we get

```json
{
    "increase(uint256)" : "30f3f0db",
    "m()"               : "5a2ee019",
    "override(uint256)" : "94d9e61c"
}
```

---

## Typesafety (on-chain)
- Work underway for strongly typed languages targeting EVM
- Typesafe EVM language wouldn't necessarily have prevented infamous bugs. We'd need session types or similar.
- Fundamental problem is call-out from turingcomplete executable to turing complete executable. Type level information not preserved on EVM.

---

## Typesafety (off-chain)

### Prevent catastrophes

- Encoding errors
  
- Improper value transfer

- Function/argument mismatch

## Conveniences

- Migrations / CD-CI

- Type safety
- 
---

> The token sale kicked off on schedule at 4:00pm UTC. About 20 minutes in, we realized something was awry with the contract transfer address. Whilst generating the contract bytes for deployment, a mistake was made defining the constructor parameters. Instead of a quoted string for an address, a Javascript hex string was used, i.e: “0x03e4B00B607d09811b0Fa61Cf636a6460861939F”
This resulted in an address in the byte code that looked very much like the actual address, but was not, i.e: “0x3e4b00b607d0980668ca6e50201576b00000000.” This address was incorrectly verified before deployment due to its similarities.

REX token sale (7/31/2017)

---

![100%](images/rex.png)

---
Subtle changes leading to broken application code

```javascript
contract A {
  
  uint n;
  
  function A (uint _arg) {
    n = _arg;
  }
  
}
```

```javascript
contract A {

  int n;
  
  function A (int _arg) {
    n = _arg;
  }
  
}
```

---
