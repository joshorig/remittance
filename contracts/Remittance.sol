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
  }

  event LogRemittanceRequest(address indexed sender, uint amount, uint fee, uint deadline);
  event LogWithdrawal(address indexed recipient, uint amount);
  event LogRefund(address indexed sender, uint amount);

  mapping (bytes32 => RemittanceRequestStruct) remittanceRequests;

  uint public requiredGas = 40712;

  function requestRemittance(bytes32 _publicKey, uint _duration)
  public
  payable
  {
    uint fee = requiredGas * tx.gasprice; //safe multiply
    require(msg.value > fee);
    uint amount = msg.value-fee;
    uint deadline = block.number+_duration;
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(!remittanceRequestStruct.isValue);
    remittanceRequestStruct.isValue = true;
    remittanceRequestStruct.amount = amount;
    remittanceRequestStruct.fee = fee;
    remittanceRequestStruct.publicKey = _publicKey;
    remittanceRequestStruct.deadline = deadline;
    remittanceRequestStruct.sender = msg.sender;
    LogRemittanceRequest(msg.sender,amount,fee,deadline);
  }

  function withdraw(bytes32 _hash1, bytes32 _hash2)
  public
  noEther
  {
    bytes32 _publicKey = sha3(_hash1,_hash2);
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(remittanceRequestStruct.sender != msg.sender); //This is bad since the sender has revealed the secrets...
    require(remittanceRequestStruct.amount>0);
    require(remittanceRequestStruct.deadline >= block.number);
    uint withdrawal_amount = remittanceRequestStruct.amount;
    remittanceRequestStruct.amount = 0;
    LogWithdrawal(msg.sender,withdrawal_amount);
    msg.sender.transfer(withdrawal_amount);
  }

  function refund(bytes32 _publicKey)
  public
  noEther
  {
    RemittanceRequestStruct storage remittanceRequestStruct = remittanceRequests[_publicKey];
    require(remittanceRequestStruct.sender == msg.sender);
    require(remittanceRequestStruct.deadline<block.number);
    require(remittanceRequestStruct.amount>0);
    uint refund_amount = safeAdd(remittanceRequestStruct.amount,remittanceRequestStruct.fee);
    remittanceRequestStruct.amount = 0;
    LogRefund(msg.sender,refund_amount);
    msg.sender.transfer(refund_amount);
  }

  function safeAdd(uint a, uint b) internal constant returns (uint c) {
    assert((c = a + b) >= a);
  }

  function() {
    assert(false);
  }

}
