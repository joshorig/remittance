pragma solidity ^0.4.11;

import "./Terminable.sol";

contract Remittance is Terminable {

  struct ExchangeRequest {
    bool is_value;
    uint amount;
    uint fee;
    bytes32 public_key;
    uint deadline;
  }

  struct ExchangeVenue {
    bool is_value;
    bool is_active;
    uint fee;
  }

  uint private counter;

  event LogExchangeRequest(address indexed sender, address indexed exchange, uint amount, uint fee, uint deadline);
  event LogWithdrawal(address indexed exchange, uint256 value);
  event LogRefund(address indexed sender, uint256 value);

  mapping (address => ExchangeVenue) exchange_venues;
  mapping (address => mapping (bytes32 => ExchangeRequest)) exchange_requests;
  address[] exchange_venue_addresses;


  uint public required_gas = 41580; //update for request method

  function requestExchange(address _exchange_venue, bytes32 _public_key, uint _duration) public payable returns(bytes32 _id)  {
    uint fee = required_gas * tx.gasprice; //safe multiply
    require(msg.value > fee && msg.sender.balance >= msg.value);
    require(exchange_venues[_exchange_venue].is_value && exchange_venues[_exchange_venue].is_active); //exchange must exist and be active
    uint amount = msg.value-fee;
    uint deadline = block.number+_duration;
    _id = generateId(_exchange_venue,msg.sender);
    exchange_requests[_exchange_venue][_public_key].is_value = true;
    exchange_requests[_exchange_venue][_public_key].amount = amount;
    exchange_requests[_exchange_venue][_public_key].fee = fee;
    exchange_requests[_exchange_venue][_public_key].public_key = _public_key;
    exchange_requests[_exchange_venue][_public_key].deadline = deadline;
    LogExchangeRequest(msg.sender,_exchange_venue,amount,fee,deadline);
  }

  function checkSha3(bytes32 _hash1, bytes32 _hash2) constant returns (bytes32)
  {
    return sha3(_hash1,_hash2);
  }

  function withdraw(bytes32 _public_key, bytes32 _hash1, bytes32 _hash2) public returns (bool success) {
    require(exchange_venues[msg.sender].is_value);
    require(exchange_requests[msg.sender][_public_key].is_value);
    require(sha3(_hash1,_hash2) == exchange_requests[msg.sender][_public_key].public_key);
    uint withdrawal_amount = exchange_requests[msg.sender][_public_key].amount;
    exchange_requests[msg.sender][_public_key].is_value = false;
    msg.sender.transfer(withdrawal_amount);
    LogWithdrawal(msg.sender,withdrawal_amount);
    return true;
  }

  function refund(bytes32 _public_key, address _exchange_venue) public returns (bool success) {
    require(exchange_venues[_exchange_venue].is_value);
    require(exchange_requests[_exchange_venue][_public_key].is_value);
    require(exchange_requests[_exchange_venue][_public_key].deadline<block.number);
    exchange_requests[_exchange_venue][_public_key].is_value = false;
    uint refund_amount = safeAdd(exchange_requests[_exchange_venue][_public_key].amount,exchange_requests[_exchange_venue][_public_key].fee);
    msg.sender.transfer(refund_amount);
    LogRefund(msg.sender,refund_amount);
    return true;
  }

  function registerExchangeVenue(uint _fee) public returns (bool success) {
    require(!exchange_venues[msg.sender].is_value);
    exchange_venues[msg.sender].is_value = true;
    exchange_venues[msg.sender].is_active = true;
    exchange_venues[msg.sender].fee = _fee;
    exchange_venue_addresses.push(msg.sender);
    return true;
  }

  function disableExchangeVenue() public returns (bool success) {
    require(exchange_venues[msg.sender].is_value && exchange_venues[msg.sender].is_active);
    exchange_venues[msg.sender].is_active = false;
    return true;
  }

  function updateExchangeFee(uint _fee) public returns (bool success) {
    require(exchange_venues[msg.sender].is_value);
    exchange_venues[msg.sender].fee = _fee;
    return true;
  }

  function activeExchanges() public constant returns (address[] exchanges, uint[] fees, bool[] active) {
    address[] memory _exchanges = new address[](exchange_venue_addresses.length);
    uint[] memory _fees = new uint[](exchange_venue_addresses.length);
    bool[] memory _active = new bool[](exchange_venue_addresses.length);
    for(uint i; i<exchange_venue_addresses.length; i++) {
      if(exchange_venues[exchange_venue_addresses[i]].is_value && exchange_venues[exchange_venue_addresses[i]].is_active) {
        _exchanges[i] = exchange_venue_addresses[i];
        _fees[i] = exchange_venues[exchange_venue_addresses[i]].fee;
        _active[i] = exchange_venues[exchange_venue_addresses[i]].is_active;
      }
    }
    return (_exchanges,_fees,_active);
  }

  function generateId(address _exchange_venue, address _sender) internal returns (bytes32) {
    return keccak256(_exchange_venue,_sender,counter++);
  }

  function safeAdd(uint a, uint b) internal constant returns (uint c) {
    assert((c = a + b) >= a);
  }

}
