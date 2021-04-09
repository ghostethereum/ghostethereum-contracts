const Migrations = artifacts.require("SubscriptionContract");

module.exports = function (deployer) {
  deployer.deploy(Migrations, {
    from: "0xB04E5c6a6A0d509C558E8dBFE8BB117C770260D9",
  });
};
