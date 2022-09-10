require("@nomiclabs/hardhat-waffle");
require('hardhat-deploy');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-ethers");
require('hardhat-abi-exporter');
// require("hardhat-deploy-ethers");


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{ version: "0.8.4", settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
      }, { version: '0.5.5'},  { version: '0.5.16'}]
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    tester: {
      default: 1
    },
  },
  networks: {
    hardhat: {
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org/',
      accounts: process.env.KEY ? [`0x${process.env.KEY}`] : []
    },
  },
  external: {
    contracts: [
      {
        artifacts: 'node_modules/@openzeppelin/build',
      },
    ],
  },
};
