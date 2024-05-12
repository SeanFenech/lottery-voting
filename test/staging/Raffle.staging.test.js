const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle unit tests", async function () {
          console.log("Not")
          let raffle, raffleEntranceFee, deployer

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              const raffleDeployment = await deployments.get("Raffle")
              raffle = await ethers.getContractAt(raffleDeployment.abi, raffleDeployment.address)
              raffleEntranceFee = await raffle.getEntranceFee()
          })

          //waay too big
          describe("fulfillRandomWords", function () {
              it("works with live Chainlink keeapers/automation, and Chainlink VRF, we get a random winner", async function () {
                  const startingTimeStamp = await raffle.getLatestTimeStamp()
                  const deployerAccount = await ethers.getSigners()
                  //setup listener before enter raffle (should have done in unit test too, there we control blockchain so was fine, but here absolutely must, in case blockchain is really quick)
                  await new Promise(async (resolve, reject) => {
                      raffle.once("WinnerPicked", async function () {
                          //listener added
                          console.log("WinnerPicked event fired! (And detected!)")
                          try {
                              const recentWinner = await raffle.getRecentWinner()
                              const raffleState = await raffle.getRaffleState()
                              const endingTimeStamp = await raffle.getLatestTimeStamp()
                              const numPlayers = await raffle.getNumberOfPlayers()
                              const winnerEndingBalance = await ethers.provider.getBalance(
                                  accounts[0],
                              )

                              await expect(raffle.getPlayer(0)).to.be.reverted
                              assert.equal(recentWinner.toString(), accounts[0].getAddress())
                              assert.equal(raffleState, 0)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance + BigInt(raffleEntranceFee),
                              )
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      //enter raffle
                      await raffle.enterRaffle({ value: raffleEntranceFee })
                      const winnerStartingBalance = await ethers.provider.getBalance(accounts[0])
                  })
              })
          })
      })
