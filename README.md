# Core-CRC2
CRC2 token standard reference implementation.

## CRC2 token standard.

CRC2 is a superset of the [CRC1](https://github.com/core-coin/CIP/issues/1) token standard. It is a step forward towards economic abstraction at the application/contract level allowing the use of tokens as first class value transfer assets in smart contract development. It is also a more safe standard as it doesn't allow token transfers to contracts that don't support token receiving and handling.

```js
contract CRC2 {
  function transfer(address to, uint value, bytes data) {
        uint codeLength;
        assembly {
            codeLength := extcodesize(_to)
        }
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        if(codeLength>0) {
            // Require proper transaction handling.
            CRC2Receiver receiver = CRC2Receiver(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }
    }
}
```

### API

CRC2 requires contract to implement the `CRC2Receiver` interface in order to receive tokens. If a user tries to send CRC2 tokens to a non-receiver contract the function will throw in the same way that it would if you sent ether to a contract without the called function being `payable`.

An example of the high-level API for a receiver contract is:

```solidity
contract ExampleReceiver is StandardReceiver {
  function foo() tokenPayable {
    LogTokenPayable(tkn.addr, tkn.sender, tkn.value);
  }

  function () tokenPayable {
    LogTokenPayable(tkn.addr, tkn.sender, tkn.value);
  }

  event LogTokenPayable(address token, address sender, uint value);
}
```

Where functions that have the `tokenPayable` can only be called via a token fallback and inside the functions you have access to the `tkn` struct that tries to mimic the `msg` struct used for ether calls.

The function `foo()` will be called when a user transfers CRC2 tokens to the receiver address.

```solidity
  // 0xc2985578 is the identifier for function foo. Sending it in the data parameter of a tx will result in the function being called.

  crc2.transfer(receiverAddress, 10, 0xc2985578)
```

What happens under the hood is that the CRC2 token will detect it is sending tokens to a contract address, and after setting the correct balances it will call the `tokenFallback` function on the receiver with the specified data. `StandardReceiver` will set the correct values for the `tkn` variables and then perform a `delegatecall` to itself with the specified data, this will result in the call to the desired function in the contract.

The current `tkn` values are:

- `tkn.sender` the original `msg.sender` to the token contract, the address originating the token transfer.
  - For user originated transfers sender will be equal to `tx.origin`
  - For contract originated transfers, `tx.origin` will be the user that made the transaction to that contract.

- `tkn.origin` the origin address from whose balance the tokens are sent
  - For `transfer()`, it will be the same as `tkn.sender`
  - For `transferFrom()`, it will be the address that created the allowance in the token contract

- `tkn.value` the amount of tokens sent
- `tkn.data` arbitrary data sent with the token transfer. Simulates ether `tx.data`.
- `tkn.sig` the first 4 bytes of `tx.data` that determine what function is called.

### The main goals of developing CRC2 token standard were:
  1. Accidentally lost tokens inside contracts: there are two different ways to transfer CRC1 tokens depending on is the receiver address a contract or a wallet address. You should call `transfer` to send tokens to a wallet address or call `approve` on token contract then `transferFrom` on receiver contract to send tokens to contract. Accidentally call of `transfer` function to a contract address will cause a loss of tokens inside receiver contract.
  2. Inability of handling incoming token transactions: CRC1 token transaction is a call of `transfer` function inside token contract. CRC1 token contract is not notifying receiver that transaction occurs. Also there is no way to handle incoming token transactions on contract and no way to reject any non-supported tokens.
  3. CRC1 token transaction between wallet address and contract is a couple of two different transactions in fact: You should call `approve` on token contract and then call `transferFrom` on another contract when you want to deposit your tokens intor it.
  4. Core transactions and token transactions behave different: one of the goals of developing CRC2 was to make token transactions similar to Core transactions to avoid users mistakes when transferring tokens and make interaction with token transactions easier for contract developers.

### CRC2 advantages.
  1. Provides a possibility to avoid accidentally lost tokens inside contracts that are not designed to work with sent tokens.
  2. Allows users to send their tokens anywhere with one function `transfer`. No difference between is the receiver a contract or not. No need to learn how token contract is working for regular user to send tokens.
  3. Allows contract developers to handle incoming token transactions.
  4. CRC2 `transfer` to contract consumes 2 times less gas than CRC1 `approve` and `transferFrom` at receiver contract.
  5. Allows to deposit tokens intor contract with a single transaction. Prevents extra blockchain bloating.
  6. Makes token transactions similar to Ether transactions.

  CRC2 tokens are backwards compatible with CRC1 tokens. It means that CRC2 supports every CRC1 functional and contracts or services working with CRC1 tokens will work with CRC2 tokens correctly.
CRC2 tokens should be sent by calling `transfer` function on token contract with no difference is receiver a contract or a wallet address. If the receiver is a wallet CRC2 token transfer will be same to CRC1 transfer. If the receiver is a contract CRC2 token contract will try to call `tokenFallback` function on receiver contract. If there is no `tokenFallback` function on receiver contract transaction will fail. `tokenFallback` function is analogue of `fallback` function for Core transactions. It can be used to handle incoming transactions. There is a way to attach `bytes _data` to token transaction similar to `_data` attached to Ether transactions. It will pass through token contract and will be handled by `tokenFallback` function on receiver contract. There is also a way to call `transfer` function on CRC2 token contract with no data argument or using CRC1 ABI with no data on `transfer` function. In this case `_data` will be empty bytes array.
