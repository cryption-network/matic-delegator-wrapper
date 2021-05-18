// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");
const ethers = hre.ethers;
const config = require('./masterChefConfig.json');
async function main() {  
  
  const [deployer] = await ethers.getSigners();

  const MasterChef = await ethers.getContractFactory("MasterChef");

  const masterChef = await MasterChef.deploy(
    config.rewardToken,
    config.farmableSupply,
    config.validatorSharesLPToken,
    config.blockReward,
    config.startBlock,
    config.endBlock,
    config.bonusEndBlock,
    config.bonus
  );

  await masterChef.deployed();
  console.log("masterchef deployed at " + masterChef.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
