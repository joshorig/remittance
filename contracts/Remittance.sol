pragma solidity ^0.4.11;

import "./Terminable.sol";

contract Remittance is Terminable {

  modifier noEther() {
      assert(msg.value == 0);
      _;
  }

  struct RemittanceRequestStruct {
    bool isValue;
    uint amount;
    uint fee;
    uint deadline;
    bytes32 publicKey;
    address sender;
    address recipient;
  }

  event LogRemittanceRequest(address indexed sender, address indexed recipient, uint amount, uint fee, uint deadline);
  event LogWithdrawal(address indexed recipient, uint amount);
  event LogRefund(address indexed sender, uint amount);

  mapping (bytes32 => RemittanceRequestStruct) remittanceRequests;

  uint public requiredGas = 40712;

  function requestRemittance(bytes32 _publicKey, address _recipient, uint _duration)
  public
  payable
  {
    uint fee = requiredGas * tx.gasprice; //safe multiply
    require(msg.value > fee);
    require(_recipient != address(0x0));
    uint amount = msg.value-fee;
    uint deadline = block.number+_duration;
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(!remittanceRequestStruct.isValue); // we cannot use the same _publicKey previously used
    remittanceRequestStruct.isValue = true;
    remittanceRequestStruct.amount = amount;
    remittanceRequestStruct.fee = fee;
    remittanceRequestStruct.publicKey = _publicKey;
    remittanceRequestStruct.deadline = deadline;
    remittanceRequestStruct.sender = msg.sender;
    remittanceRequestStruct.recipient = _recipient;
    LogRemittanceRequest(msg.sender,_recipient,amount,fee,deadline);
  }

  function withdraw(bytes32 _hash1, bytes32 _hash2)
  public
  noEther
  returns (bool success)
  {
    bytes32 _publicKey = sha3(_hash1,_hash2);
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(remittanceRequestStruct.recipient == msg.sender);
    require(remittanceRequestStruct.amount>0);
    require(remittanceRequestStruct.deadline >= block.number);
    uint withdrawal_amount = remittanceRequestStruct.amount;
    remittanceRequestStruct.amount = 0;
    LogWithdrawal(msg.sender,withdrawal_amount);
    msg.sender.transfer(withdrawal_amount);
    return true;
  }

  function refund(bytes32 _publicKey)
  public
  noEther
  returns (bool success)
  {
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(remittanceRequestStruct.sender == msg.sender);
    require(remittanceRequestStruct.deadline<block.number);
    require(remittanceRequestStruct.amount>0);
    uint refund_amount = safeAdd(remittanceRequestStruct.amount,remittanceRequestStruct.fee);
    remittanceRequestStruct.amount = 0;
    LogRefund(msg.sender,refund_amount);
    msg.sender.transfer(refund_amount);
    return true;
  }

  function safeAdd(uint a, uint b) internal constant returns (uint c) {
    assert((c = a + b) >= a);
  }

  function() {
    assert(false);
  }

}
