const { run } = require("hardhat")

async function verify(contractAddress, args) {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            //verify command passing verify as a parameter.We do it to be specific. To see params do: yarn hardhat verify --help
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already Verfied!")
        } else {
            console.log(e)
        }
    }
}

module.exports = { verify }
