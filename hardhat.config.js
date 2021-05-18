require("@nomiclabs/hardhat-waffle");

const INFURA_API = ; // network api key from infura
const PRIVATE_KEY = ''; // replace with private key without 0x
const defaultNetwork = "localhost";

// require("@nomiclabs/hardhat-solhint");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

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
  defaultNetwork,
  networks: {
    localhost: {
      url: "http://localhost:8545", // uses account 0 of the hardhat node to deploy
    },
    mainnet: {
      url: INFURA_API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    rinkeby: {
      url: INFURA_API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    kovan: {
      url: INFURA_API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    ropsten: {
      url: INFURA_API,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    goerli: {
      url: INFURA_API,
      accounts: [`0x${PRIVATE_KEY}`],
      gasPrice: 100000000000
    },
    hardhat: {
      forking: {
        url: INFURA_API,
        chainId: 42,
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.7.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};


