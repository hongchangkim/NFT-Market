
const HDWalletProvider = require("truffle-hdwallet-provider-klaytn");

const fs = require("fs");
const privateKey = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    development: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*"
    },
    dashboard: {
    },
    // baobab: {
    //   host: '127.0.0.1',
    //   port: 8551,
    //   from: '0x0bc9ea9eaf712de8518d863ba3746be6a34cbd03', // enter your account address
    //   network_id: '1001', // Baobab network id
    //   gas: 20000000, // transaction gas limit
    //   gasPrice: 250000000000, // gasPrice of Baobab is 250 ston
    // },
    baobab: {
      provider: () => {
        return new HDWalletProvider(privateKey, "https://api.baobab.klaytn.net:8651");
      },
      network_id: '1001', //Klaytn baobab testnet's network id
      gas: '8500000',
      gasPrice: null
    },
  },
  // compilers: {
  //   solc: {
  //     version: "0.8.13",
  //   }
  // },
  compilers: {
    solc: {
      version: "0.8.13", // Fetch exact version from solc-bin (default: truffle's version)
      settings: { // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    }
  },


  db: {
    enabled: false,
    host: "127.0.0.1",
  }
};
