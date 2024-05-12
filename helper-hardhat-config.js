const networkConfig = {
    11155111: {
        name: "sepolia",
        vrfCoordinatorV2Plus: "0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B",
        vrfCoordinatorV2: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
        gasLane: "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae", //30 gwei
        subscriptionId:
            "65054368195214660697152339603844882790894571056543590270190034708116614711260",
        callbackGasLimit: "2000000", //2mil
    },
    31337: {
        name: "hardhat",
        gasLane: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", //can put anything wont use
        callbackGasLimit: "2000000", //2mil
    },
    421614: {
        name: "arbitrum_sepolia",
        vrfCoordinatorV2Plus: "0x5CE8D5A2BC84beb22a398CCA51996F7930313D61",
        gasLane: "0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be", //30 gwei
        subscriptionId:
            "19576272799070600113980834601362987554320060521735788393330467306559580037119",
        callbackGasLimit: "2500000", //2.5mil
    },
    80002: {
        name: "polygon_amoy",
        vrfCoordinatorV2Plus: "0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2",
        gasLane: "0x816bedba8a50b294e5cbd47842baf240c2385f2eaf719edbd4f250a137a8c899", //30 gwei
        subscriptionId: "", //Need to add
        callbackGasLimit: "2000000", //2mil
    },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = { networkConfig, developmentChains }
