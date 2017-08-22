pragma solidity ^0.4.2;

import "./Owned.sol";

contract Terminable is Owned {
    function terminate() onlyOwner {
        selfdestruct(owner);
    }
}
