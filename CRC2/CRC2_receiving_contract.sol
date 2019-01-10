pragma solidity ^0.4.11;

 /**
 * @title Contract that will work with CRC2 tokens.
 */
 
contract CRC2ReceivingContract { 
/**
 * @dev Standard CRC2 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
    function tokenFallback(address _from, uint _value, bytes _data);
}
