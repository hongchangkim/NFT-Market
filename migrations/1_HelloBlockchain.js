
const HNFT = artifacts.require("HNFT");

module.exports = function (deployer) {
  deployer.deploy(HNFT, "HNFT");
};