pragma solidity ^0.4.11;

import "./Terminable.sol";

contract Remittance is Terminable {

  struct RemittanceRequestStruct {
    bool is_value;
    uint amount;
    uint fee;
    bytes32 public_key;
    uint deadline;
  }

  struct RemittanceVenueStruct {
    bool is_value;
    bool is_active;
    uint fee;
  }

  uint private counter;

  event LogRemittanceRequest(address indexed sender, address indexed exchange, uint amount, uint fee, uint deadline);
  event LogWithdrawal(address indexed exchange, uint256 value);
  event LogRefund(address indexed sender, uint256 value);

  mapping (address => RemittanceVenueStruct) public remittanceVenues;
  mapping (address => mapping (bytes32 => RemittanceRequestStruct)) remittanceRequests;
  address[] exchange_venue_addresses;


  uint public required_gas = 41580; //update for request method

  function requestRemittance(address _exchange_venue, bytes32 _public_key, uint _duration)
  public
  payable
  {
    uint fee = required_gas * tx.gasprice; //safe multiply
    require(msg.value > fee && msg.sender.balance >= msg.value);
    require(remittanceVenues[_exchange_venue].is_value && remittanceVenues[_exchange_venue].is_active); //exchange must exist and be active
    uint amount = msg.value-fee;
    uint deadline = block.number+_duration;
    remittanceRequests[_exchange_venue][_public_key].is_value = true;
    remittanceRequests[_exchange_venue][_public_key].amount = amount;
    remittanceRequests[_exchange_venue][_public_key].fee = fee;
    remittanceRequests[_exchange_venue][_public_key].public_key = _public_key;
    remittanceRequests[_exchange_venue][_public_key].deadline = deadline;
    LogRemittanceRequest(msg.sender,_exchange_venue,amount,fee,deadline);
  }

  function withdraw(bytes32 _public_key, bytes32 _hash1, bytes32 _hash2)
  public
  {
    require(remittanceVenues[msg.sender].is_value);
    require(remittanceRequests[msg.sender][_public_key].is_value);
    require(sha3(_hash1,_hash2) == remittanceRequests[msg.sender][_public_key].public_key);
    uint withdrawal_amount = remittanceRequests[msg.sender][_public_key].amount;
    remittanceRequests[msg.sender][_public_key].is_value = false;
    LogWithdrawal(msg.sender,withdrawal_amount);
    msg.sender.transfer(withdrawal_amount);
  }

  function refund(bytes32 _public_key, address _exchange_venue)
  public
  {
    require(remittanceVenues[_exchange_venue].is_value);
    require(remittanceRequests[_exchange_venue][_public_key].is_value);
    require(remittanceRequests[_exchange_venue][_public_key].deadline<block.number);
    remittanceRequests[_exchange_venue][_public_key].is_value = false;
    uint refund_amount = safeAdd(remittanceRequests[_exchange_venue][_public_key].amount,remittanceRequests[_exchange_venue][_public_key].fee);
    LogRefund(msg.sender,refund_amount);
    msg.sender.transfer(refund_amount);
  }

  function registerRemittanceVenue(uint _fee)
  public
  {
    require(!remittanceVenues[msg.sender].is_value);
    remittanceVenues[msg.sender].is_value = true;
    remittanceVenues[msg.sender].is_active = true;
    remittanceVenues[msg.sender].fee = _fee;
  }

  function disableRemittanceVenue()
  public
  {
    require(remittanceVenues[msg.sender].is_value && remittanceVenues[msg.sender].is_active);
    remittanceVenues[msg.sender].is_active = false;
  }

  function updateRemittanceFee(uint _fee) public {
    require(remittanceVenues[msg.sender].is_value);
    remittanceVenues[msg.sender].fee = _fee;
  }

  function safeAdd(uint a, uint b) internal constant returns (uint c) {
    assert((c = a + b) >= a);
  }

}
