const { network } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

const VRF_SUB_FUND_AMOUNT = ethers.parseUnits("30")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    let vrfCoordinatorV2Address, subscriptionId, vrfCoordinatorV2Mock

    if (developmentChains.includes(network.name)) {
        const contractAddress = (await deployments.get("VRFCoordinatorV2Mock")).address
        vrfCoordinatorV2Mock = await ethers.getContractAt("VRFCoordinatorV2Mock", contractAddress)
        vrfCoordinatorV2Address = await vrfCoordinatorV2Mock.getAddress()

        const transactionResponse = await vrfCoordinatorV2Mock.createSubscription()
        const transactionReceipt = await transactionResponse.wait(1)
        subscriptionId = transactionReceipt.logs[0].topics[1]

        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, VRF_SUB_FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2Plus"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const gasLane = networkConfig[chainId]["gasLane"]
    const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]

    const population = [
        "0x403b5045F43FFE3137F44c80157f866f654Ee98b",
        "0x94afbC2B77175742E17fAEd4b87932bA65C9F10C",
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    ]
    const electionFrequency = 30 //2 minutes
    const candidateInterval = 30
    const voterInterval = 30

    const args = [
        population,
        "0x876Bf45B93CCa239d27Da5Bb4D4215649347C064",
        electionFrequency,
        candidateInterval,
        voterInterval,
        vrfCoordinatorV2Address,
        gasLane,
        subscriptionId,
        callbackGasLimit,
    ]
    const lotteryVoting = await deploy("LotteryVoting", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    console.log("Deployed!")

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(lotteryVoting.address, args)
    }

    if (developmentChains.includes(network.name)) {
        await vrfCoordinatorV2Mock.addConsumer(subscriptionId, await lotteryVoting.address)
    }

    log("__________________________________________")
}

module.exports.tags = ["all", "mocks"]
