var Owned = artifacts.require("./Owned.sol");
var Terminable = artifacts.require("./Terminable.sol");
var Remittance = artifacts.require("./Remittance.sol");

module.exports = function(deployer) {
  deployer.deploy(Owned);
  deployer.link(Owned, Terminable);
  deployer.deploy(Terminable);
  deployer.link(Terminable, Remittance);
  deployer.deploy(Remittance);
};
