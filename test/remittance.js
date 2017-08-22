var Remittance = artifacts.require("./Remittance.sol");

var remittance;
var exchange_accounts;  //fees in wei
var password1 = "password1";
var password2 = "password2";
var amount_to_send = 10;
var duration = 5; //5 blocks

function before(Remittance,accounts,done)
{
  exchange_accounts = [{account: accounts[1], fee: 0},{account: accounts[2], fee: 200}];
  Remittance.deployed().then(function (instance) { //deploy it
  remittance = instance;

  Promise.all(exchange_accounts.map((exchnage) => remittance.registerRemittanceVenue(exchnage.fee, { from: exchnage.account })))
    .then(() => done());
  });
}

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

  beforeEach(function (done) {
    before(Remittance,accounts,done);
  });

  it("Should create exchange request correctly", done => {

    var passwordHash1 = solSha3(password1);
    var passwordHash2 = solSha3(password2);
    var public_key = solSha3(passwordHash1,passwordHash2);

    remittance.requestRemittance(exchange_accounts[0].account, public_key, duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether")})
    .then((txObject) => {
      //assert.isString(id.,"Did not create exchange request with an id");
      done();
    });
  });

});

contract('Remittance', function(accounts) {

  beforeEach(function (done) {
    before(Remittance,accounts,done);
  });

  it("Should allow exchange to withdraw correctly", done => {

    var passwordHash1 = solSha3(password1);
    var passwordHash2 = solSha3(password2);
    var public_key = solSha3(passwordHash1,passwordHash2);
    var starting_balance;
    var ending_balance;

    remittance.requestRemittance(exchange_accounts[0].account, public_key, duration, {from: accounts[0],value: web3.toWei(amount_to_send,"ether")})
    .then((txObject) => {
      starting_balance = web3.eth.getBalance(exchange_accounts[0].account);
      remittance.withdraw(public_key, passwordHash1, passwordHash2, {from: exchange_accounts[0].account})
      .then((success) => {
        ending_balance = web3.eth.getBalance(exchange_accounts[0].account);
        assert(ending_balance.greaterThan(starting_balance),"Did not withdraw to exchange wallet");
        done();
      });


    });
  });

});

contract('Remittance', function(accounts) {

  beforeEach(function (done) {
    before(Remittance,accounts,done);
  });
  var updated_fee = 300;
  it("Should update exchnage fee correctly", done => {
    remittance.updateRemittanceFee(updated_fee, {from: exchange_accounts[0].account})
    .then((txObject) => {

      done();

    });
  });
});

contract('Remittance', function(accounts) {

  beforeEach(function (done) {
    before(Remittance,accounts,done);
  });

  it("Should disable exchange", done => {
    remittance.disableRemittanceVenue({from: exchange_accounts[0].account})
    .then((txObject) => {

        done();
      });
  });
});
