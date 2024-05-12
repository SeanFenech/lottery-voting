require("@nomicfoundation/hardhat-toolbox")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0xkey"

const SEPOLIA_CHAIN_ID = 11155111
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "https://eth-sepolia"

const ARBITRUM_SEPOLIA_CHAIN_ID = 421614
const ARBITRUM_SEPOLIA_RPC_URL = process.env.ARBITRUM_SEPOLIA_RPC_URL

const POLYGON_AMOY_CHAIN_ID = 80002
const POLYGON_AMOY_RPC_URL = process.env.POLYGON_AMOY_RPC_URL

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "key"
const ARBITRUM_SEPOLIA_API_KEY = process.env.ARBITRUM_SEPOLIA_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "key"

const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key"

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {},
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: SEPOLIA_CHAIN_ID,
            blockConfirmations: 6,
        },
        arbitrum_sepolia: {
            url: ARBITRUM_SEPOLIA_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
            blockConfirmations: 6,
            allowUnlimitedContractSize: true,
        },
        polygon_amoy: {
            url: POLYGON_AMOY_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: POLYGON_AMOY_CHAIN_ID,
            blockConfirmations: 6,
        },
        localhost: {
            url: "http://127.0.0.1:8545/",
            chainId: 31337,
        },
    },
    solidity: {
        compilers: [{ version: "0.8.6" }, { version: "0.8.19" }],
    },
    etherscan: {
        apiKey: {
            sepolia: ETHERSCAN_API_KEY,
            arbitrumSepolia: ARBITRUM_SEPOLIA_API_KEY,
            polygon_amoy: POLYGONSCAN_API_KEY,
        },
        customChains: [
            {
                network: "polygon_amoy",
                chainId: 80002,
                urls: {
                    apiURL: "https://api-amoy.polygonscan.com/api",
                    browserURL: "",
                },
            },
        ],
    },
    gasReporter: {
        enabled: false,
        OutputFile: "Gas Report.txt",
        currency: "EUR",
        coinmarketcap: COINMARKETCAP_API_KEY,
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        player: {
            default: 1,
        },
    },
    mocha: {
        timeout: 200000, //200 secs
    },
}
