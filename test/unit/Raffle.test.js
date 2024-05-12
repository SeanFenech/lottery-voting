const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

//Doesnt work because in 00-deploy-mocks, a vrfVoordinatorV2 is used, while on network only 2.5 can be used and it does not provide a mock, and raffle.sol is for v2.5 (rather be able to use on testnet obviously)
!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle unit tests", async function () {
          console.log("only the unit")
          let raffle, vrfCoordinatorV2Mock, raffleEntranceFee, deployer, interval
          const chainId = network.config.chainId

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["all"])
              const raffleDeployment = await deployments.get("Raffle")
              raffle = await ethers.getContractAt(raffleDeployment.abi, raffleDeployment.address)

              const vrfCoordinatorV2MockDeployment = await deployments.get("VRFCoordinatorV2Mock")
              vrfCoordinatorV2Mock = await ethers.getContractAt(
                  vrfCoordinatorV2MockDeployment.abi,
                  vrfCoordinatorV2MockDeployment.address,
              )
              raffleEntranceFee = await raffle.getEntranceFee()
              interval = await raffle.getInterval()
          })

          describe("constructor", function () {
              it("initializes the raffle correctly", async function () {
                  //Ideally one assert per it
                  const raffleState = await raffle.getRaffleState()
                  assert.equal(raffleState.toString(), "0")
                  assert.equal(interval.toString(), networkConfig[chainId]["interval"])
              })
          })

          describe("enterRaffle", function () {
              it("reverts when you don't pay enough", async function () {
                  await expect(raffle.enterRaffle()).to.be.revertedWithCustomError(
                      raffle,
                      "Raffle__NotEnoughETHEntered",
                  )
              })
              it("records players when they enter", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  const playerFromContract = await raffle.getPlayer(0)
                  assert.equal(playerFromContract, deployer)
              })
              it("emits event on enter", async function () {
                  await expect(raffle.enterRaffle({ value: raffleEntranceFee })).to.emit(
                      raffle,
                      "RaffleEnter",
                  )
              })
              it("doesn't allow entrance when raffle is calculating", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  //first make checkUpkeep true
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
                  //We pretend to be chainlink keeper
                  await raffle.performUpkeep()
                  await expect(
                      raffle.enterRaffle({ value: raffleEntranceFee }),
                  ).to.be.revertedWithCustomError(raffle, "Raffle__NotOpen")
              })
          })

          describe("checkUpkeep", function () {
              it("returns false if people haven't sent any eth", async function () {
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])

                  //callStatic to simulate transaction
                  const { upkeepNeeded } = await raffle.checkUpKeep.staticCall("0x") //blank bytes object
                  assert(!upkeepNeeded)
              })
              it("returns false if the raffle isn't open", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
                  await raffle.performUpkeep()
                  const raffleState = await raffle.getRaffleState()
                  const { upkeepNeeded } = await raffle.checkUpKeep.staticCall("0x") //blank bytes object
                  assert.equal(raffleState.toString(), "1")
                  assert(!upkeepNeeded)
              })
              it("returns false if enough time hasn't passed", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) - 2])
                  await network.provider.send("evm_mine", [])
                  const { upkeepNeeded } = await raffle.checkUpKeep.staticCall("0x") //blank bytes object
                  assert(!upkeepNeeded)
              })
              it("returns true if enough time has passed, has players, eth, and is open", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
                  const { upkeepNeeded } = await raffle.checkUpKeep.staticCall("0x") //blank bytes object
                  assert(upkeepNeeded)
              })
          })

          describe("performUpkeep", function () {
              it("can only run if checkUpkeep is true", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
                  const tx = await raffle.performUpkeep()
                  assert(tx)
              })
              it("reverts when checkUpKeep is false", async function () {
                  await expect(raffle.performUpkeep()).to.be.revertedWithCustomError(
                      raffle,
                      "Raffle__UpkeepNotNeeded",
                  )
              })
              it("updates the raffle state, emits an event, and calls the vrf coordinator", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
                  const txResponse = await raffle.performUpkeep()
                  const txReceipt = await txResponse.wait(1)
                  const requestId = BigInt(txReceipt.logs[0].topics[1])
                  const raffleState = await raffle.getRaffleState()
                  assert(Number(requestId) > 0)
                  assert(raffleState.toString() == "1")
              })
          })

          describe("fulfillRandomWords", function () {
              beforeEach(async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [Number(interval) + 1])
                  await network.provider.send("evm_mine", [])
              })
              it("can only be called after performUpkeep", async function () {
                  //we are pretending to be chainlink node that calls vrfCoordinatorV2Mock (which then calls raffle.fulfillRandomWords)
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(0, raffle.getAddress()),
                  ).to.be.revertedWith("nonexistent request")
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(1, raffle.getAddress()),
                  ).to.be.revertedWith("nonexistent request")
              })
              //Nest is waaayy too big
              it("picks a winner, resets the lottery, and sends money", async function () {
                  const additionalEntrants = 3
                  const startingAccountIndex = 1 //since deployer is 0
                  const accounts = await ethers.getSigners()
                  for (
                      let i = startingAccountIndex;
                      i < startingAccountIndex + additionalEntrants;
                      i++
                  ) {
                      const accountConnectedRaffle = raffle.connect(accounts[i])
                      await accountConnectedRaffle.enterRaffle({ value: raffleEntranceFee })
                  }
                  const startingTimeStamp = await raffle.getLatestTimeStamp()
                  await new Promise(async (resolve, reject) => {
                      //set up listener for winner picked event
                      raffle.once("WinnerPicked", async () => {
                          console.log("Found the event!")
                          try {
                              const recentWinner = await raffle.getRecentWinner()
                              const raffleState = await raffle.getRaffleState()
                              const endingTimeStamp = await raffle.getLatestTimeStamp()
                              const numPlayers = await raffle.getNumberOfPlayers()
                              const winnerEndingBalance =
                                  await ethers.provider.getBalance(recentWinner)

                              assert.equal(numPlayers.toString(), "0")
                              assert.equal(raffleState.toString(), "0")
                              assert(endingTimeStamp > startingTimeStamp)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  (
                                      winnerStartingBalance +
                                      (raffleEntranceFee * BigInt(additionalEntrants) +
                                          raffleEntranceFee)
                                  ).toString(),
                              )
                          } catch (e) {
                              //timeout error will be thrown is more than 200s (see mocha in hh config)
                              reject(e)
                          }
                          resolve()
                      })
                      //code needs to be inside promise else wont be executed (cos of await), but outside .once
                      //pretending to be chainlink keeper
                      const tx = await raffle.performUpkeep()
                      const txReceipt = await tx.wait(1)
                      const winnerStartingBalance = await ethers.provider.getBalance(
                          accounts[1].getAddress(),
                      )
                      //pretending to be chainlink vrf
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.logs[0].topics[2],
                          await raffle.getAddress(),
                      ) //this will cause vrf coordinator to call raffle.fulfill, which will emit winnerPicked event
                  })
              })
          })
      })
