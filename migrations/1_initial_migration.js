const Migrations = artifacts.require("SubscriptionContract");

module.exports = function (deployer) {
  deployer.deploy(Migrations, {
    from: "0x4528Ea6B59a447F9d0EaCf7F14Cde9e3388429aA",
  });
};
