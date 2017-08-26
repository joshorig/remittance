var BigNumber = require('bignumber.js');
var Remittance = artifacts.require("./Remittance.sol");

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

  var remittance;
  var password1 = "password1";
  var password2 = "password2";
  var amount_to_send = 1;
  var duration = 5; //5 blocks
  var remittanceRequest1Amount;

  var passwordHash1 = solSha3(password1);
  var passwordHash2 = solSha3(password2);
  var incorrectPasswordHash = solSha3("incorrect");
  var publicKey = solSha3(passwordHash1,passwordHash2);

  it("Should create remittance request correctly", done => {
    Remittance.deployed()
    .then((instance) => {
      remittance = instance;
      remittance.requestRemittance(publicKey, duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether")})
      .then((txObject) => {
        assert.equal(txObject.logs.length,1,"Did not log 1 event");
        var logEvent = txObject.logs[0];
        remittanceRequest1Amount = logEvent.args.amount;
        assert.equal(logEvent.event,"LogRemittanceRequest","Did not LogRemittanceRequest");
        assert.equal(logEvent.args.sender,accounts[0],"Did not LogRemittanceRequest sender correctly");
        assert.equal((remittanceRequest1Amount.plus(logEvent.args.fee)).valueOf(),web3.toWei(amount_to_send,"ether"),"Did not LogRemittanceRequest amount and fee correctly");
        assert.equal(logEvent.args.deadline.valueOf(),txObject.receipt.blockNumber+duration,"Did not LogRemittanceRequest deadline correctly");
        done();
      });
    });
  });

  it("Should not create remittance request with previoulsy used publicKey", done => {
    Remittance.deployed()
    .then((instance) => {
      remittance = instance;
      remittance.requestRemittance(publicKey, duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether")})
      .then(() => {
        assert.fail("", "", "Did not throw invalid opcode VM exception");
      })
      .catch((e) => {
        assert.include(e+"","invalid opcode","Did not throw invalid opcode VM exception");
        done();
      });
    });
  });

  it("Should not allow withdrawal with incorrect passwords", done => {
    Remittance.deployed()
    .then((instance) => {
      remittance = instance;
      remittance.withdraw(incorrectPasswordHash,passwordHash2, {from: accounts[1]})
      .then(() => {
        assert.fail("", "", "Did not throw invalid opcode VM exception");
      })
      .catch((e) => {
        assert.include(e+"","invalid opcode","Did not throw invalid opcode VM exception");
        done();
      });
    });
  });

  it("Should not allow withdrawal by sender", done => {
    Remittance.deployed()
    .then((instance) => {
      remittance = instance;
      remittance.withdraw(passwordHash1,passwordHash2, {from: accounts[0]})
      .then(() => {
        assert.fail("", "", "Did not throw invalid opcode VM exception");
      })
      .catch((e) => {
        assert.include(e+"","invalid opcode","Did not throw invalid opcode VM exception");
        done();
      });
    });
  });

  it("Should allow withdrawal with correct passwords", done => {
    Remittance.deployed()
    .then((instance) => {
      remittance = instance;
      remittance.withdraw(passwordHash1,passwordHash2, {from: accounts[1]})
      .then((txObject) => {
        assert.equal(txObject.logs.length,1,"Did not log 1 event");
        var logEvent = txObject.logs[0];
        assert.equal(logEvent.event,"LogWithdrawal","Did not LogWithdrawal");
        assert.equal(logEvent.args.recipient,accounts[1],"Did not log recipient correctly");
        assert.equal(logEvent.args.amount.valueOf(),remittanceRequest1Amount.valueOf(),"Did not log amount correctly");
        done();
      });
    });
  });

});
