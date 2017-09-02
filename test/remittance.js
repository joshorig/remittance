require('babel-polyfill');
const BigNumber = require('bignumber.js');
const utils = require('./helpers/Utils');
const Remittance = artifacts.require("./Remittance.sol");

function solSha3 (...args) {
    args = args.map(arg => {
        if (typeof arg === 'string') {
            if (arg.substring(0, 2) === '0x') {
                return arg.slice(2)
            } else {
                return web3.toHex(arg).slice(2)
            }
        }

        if (typeof arg === 'number') {
            return leftPad((arg).toString(16), 64, 0)
        } else {
          return ''
        }
    })

    args = args.join('')

    return web3.sha3(args, { encoding: 'hex' })
}

contract('Remittance', function(accounts) {


  const password1 = "password1";
  const password2 = "password2";
  const amount_to_send = 1;
  const duration = 5; //5 blocks

  const passwordHash1 = solSha3(password1);
  const passwordHash2 = solSha3(password2);
  const incorrectPasswordHash = solSha3("incorrect");
  const publicKey = solSha3(passwordHash1,passwordHash2);

  let remittanceRequest1Amount;
  let remittance;
  let requiredGas;

  beforeEach(async () => {
    remittance = await Remittance.deployed();
    requiredGas = await remittance.requiredGas.call();
  });

  it("Should create remittance request correctly", async () => {

    let txObject = await remittance.requestRemittance(publicKey, accounts[1], duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether")})
    let expectedFee = requiredGas.times(web3.eth.getTransaction(txObject.tx).gasPrice);
    remittanceRequest1Amount = new BigNumber(web3.toWei(amount_to_send,"ether")).minus(expectedFee);
    let expectedDeadline = new BigNumber(txObject.receipt.blockNumber).plus(new BigNumber(duration));

    assert.equal(txObject.logs.length,1,"Did not log LogRemittanceRequest event");
    let logEvent = txObject.logs[0];
    assert.equal(logEvent.event,"LogRemittanceRequest","Did not LogRemittanceRequest");
    assert.equal(logEvent.args.sender,accounts[0],"Did not log sender correctly");
    assert.equal(logEvent.args.recipient,accounts[1],"Did not log recipient correctly");
    assert.equal(logEvent.args.fee.valueOf(),expectedFee.valueOf(),"Did not log fee correctly");
    assert.equal(logEvent.args.amount.valueOf(),remittanceRequest1Amount.valueOf(),"Did not log amount correctly");
    assert.equal(logEvent.args.deadline.valueOf(),expectedDeadline.valueOf(),"Did not log deadline correctly");
  });

  it("Should not create remittance request with previoulsy used publicKey", async () => {
    try {
     let txObject = await remittance.requestRemittance(publicKey, accounts[1], duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether"), gas: utils.exceptionGatToUse});
     assert.equal(txObject.receipt.gasUsed, utils.exceptionGatToUse, "should have used all the gas");
    }
    catch (error){
      return utils.ensureException(error);
    }
  });

  it("Should not allow withdrawal with incorrect passwords", async () => {
    try {
     let txObject = await remittance.withdraw(incorrectPasswordHash,passwordHash2, {from: accounts[1], gas: utils.exceptionGatToUse});
     assert.equal(txObject.receipt.gasUsed, utils.exceptionGatToUse, "should have used all the gas");
    }
    catch (error){
      return utils.ensureException(error);
    }
  });

  it("Should not allow withdrawal if not recipient", async () => {
    try {
     let txObject = await remittance.withdraw(passwordHash1,passwordHash2, {from: accounts[2], gas: utils.exceptionGatToUse});
     assert.equal(txObject.receipt.gasUsed, utils.exceptionGatToUse, "should have used all the gas");
    }
    catch (error){
      return utils.ensureException(error);
    }
  });


  it("Should allow withdrawal with correct passwords", async () => {

      let txObject = await remittance.withdraw(passwordHash1,passwordHash2, {from: accounts[1]});
      assert.equal(txObject.logs.length,1,"Did not log 1 event");
      let logEvent = txObject.logs[0];
      assert.equal(logEvent.event,"LogWithdrawal","Did not LogWithdrawal");
      assert.equal(logEvent.args.recipient,accounts[1],"Did not log recipient correctly");
      assert.equal(logEvent.args.amount.valueOf(),remittanceRequest1Amount.valueOf(),"Did not log amount correctly");

  });

});
