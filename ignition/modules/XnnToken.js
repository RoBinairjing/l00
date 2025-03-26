const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { ethers, upgrades } = require("hardhat");

module.exports = buildModule("XnnTokenModule", (m) => {
  const xnnToken = m.contract("XnnToken");
  return { xnnToken };
});
