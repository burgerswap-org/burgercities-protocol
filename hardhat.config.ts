/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 import { HardhatUserConfig } from "hardhat/types";
 import '@openzeppelin/hardhat-upgrades';
 
 import "@nomiclabs/hardhat-waffle";
 import "@nomiclabs/hardhat-etherscan";
 import "hardhat-typechain";
 import fs from "fs";
 import path from "path";
 const USER_HOME = process.env.HOME || process.env.USERPROFILE
 let data = {
   "PrivateKey": "",
   "InfuraApiKey": "",
   "EtherscanApiKey": "",
 };
 
 let filePath = path.join(USER_HOME+'/.hardhat.data.json');
 if (fs.existsSync(filePath)) {
   let rawdata = fs.readFileSync(filePath);
   data = JSON.parse(rawdata.toString());
 }
 filePath = path.join(__dirname, `.hardhat.data.json`);
 if (fs.existsSync(filePath)) {
   let rawdata = fs.readFileSync(filePath);
   data = JSON.parse(rawdata.toString());
 }
 
 const LOWEST_OPTIMIZER_COMPILER_SETTINGS = {
   version: "0.8.9",
   settings: {
     optimizer: {
       enabled: true,
       runs: 200,
     },
     metadata: {
       bytecodeHash: 'none',
     },
   },
 }
 
 const LOWER_OPTIMIZER_COMPILER_SETTINGS = {
   version: "0.8.9",
   settings: {
     optimizer: {
       enabled: true,
       runs: 10_000,
     },
     metadata: {
       bytecodeHash: 'none',
     },
   },
 }
 
 const DEFAULT_COMPILER_SETTINGS = {
   version: "0.8.9",
   settings: {
     optimizer: {
       enabled: true,
       runs: 1_000_000,
     }
   },
 }
 
 const config: HardhatUserConfig = {
   defaultNetwork: "hardhat",
   solidity: {
     compilers: [DEFAULT_COMPILER_SETTINGS],
     overrides: {
       'contracts/HeroManage.sol': LOWER_OPTIMIZER_COMPILER_SETTINGS,
     },
   },
   networks: {
     hardhat: {},
     mainnet: {
       url: `https://mainnet.infura.io/v3/${data.InfuraApiKey}`,
       accounts: [data.PrivateKey]
     },
     goerli: {
       url: `https://goerli.infura.io/v3/${data.InfuraApiKey}`,
       accounts: [data.PrivateKey]
     },
     sepolia: {
       url: `https://sepolia.infura.io/v3/${data.InfuraApiKey}`,
       accounts: [data.PrivateKey]
     },
     bsctestnet: {
       url: `https://rpc.ankr.com/bsc_testnet_chapel`,
       accounts: [data.PrivateKey]
     },
     bscmainnet: {
       url: `https://rpc.ankr.com/bsc`,
       accounts: [data.PrivateKey]
     },
     arbitrum_goerli: {
       url: `https://arbitrum-goerli.infura.io/v3/${data.InfuraApiKey}`,
       accounts: [data.PrivateKey],
       gas: "auto",
     },
     arbitrum_mainnet: {
       url: `https://arbitrum-mainnet.infura.io/v3/${data.InfuraApiKey}`,
       accounts: [data.PrivateKey],
     },
   },
   etherscan: {
     apiKey: data.EtherscanApiKey,
   },
   paths: {
     sources: "./contracts",
     tests: "./test",
     cache: "./cache",
     artifacts: "./artifacts"
   },
   mocha: {
     timeout: 100000
   }
 };
 
 export default config;