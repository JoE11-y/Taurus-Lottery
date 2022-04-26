// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const {utils, BigNumber} = require('ethers');

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const vrfCoordinator = "0xa555fC018435bef5A13C6c6870a9d4C11DEC329C";
  const linkToken = "0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06";
  const keyhash = "0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186"
  const fee = BigNumber.from(1)
  const ticketPrice = 10**6;
  
  const Lottery = await hre.ethers.getContractFactory("Lottery");
  const lottery = await Lottery.deploy(vrfCoordinator, linkToken, keyhash, fee, ticketPrice);

  await lottery.deployed();

  console.log("Lottery deployed to:", lottery.address);
  console.log(`Verify with:\n npx hardhat verify --network networkName ${lottery.address} ${vrfCoordinator} ${linkToken} ${keyhash} ${fee} ${ticketPrice} `) 
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
