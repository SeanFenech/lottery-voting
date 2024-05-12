# Lottery Voting

Lottery Voting is an election procedure where the electorate votes for the available candidates, and the election is won at random, but each candidate has a chance equal to the proportion of the total votes that they receive.

The procedure may be effective in circumstances where the assumptions required for the other forms of democracy cannot be made.

# Project Structure

This project makes use of the hardhat framework to develop a smart contract `contracts\LotteryVoting.sol`.

A runtime verification tool, ContractLarva `\contractLarva-master`, is used to generate another solidity file `contracts\MonitoredLotteryVoting.sol`, by inputting a compatible version of the original smart contract `\contractLarva-master\src\CLCompatableLotteryVoting.sol`, and a .dea file for the specification `\contractLarva-master\src\LotteryVotingSpec.dea`.

The contract may call another contract (for secure randomness), which is why runtime verification is better suited to ensure that the contract adheres to a certain specification, rather than static verification. Static verification is difficult, even more so when external functionality has an effect.

# Smart Contract

The smart contract has four states, CLOSED, CANDIDATE_PERIOD, VOTING_PERIOD and CALCULATING, which repeat for each election. These states can be reached by having their respective functions called. These functions can be called successfully by any address, provided that the interval, which is specified at creation, has passed. The functions should make use of Chainlink Automation to be called automatically and in a decentralised fashion. This can be implemented programmatically in the contract.

Candidates can decide to run for an election, or to withdraw, during the candidate period, after which the voting period will commence where voters can vote. Withdrawing votes is not permitted. The reason for separating these periods is due to the fact that if running and voting were permitted in the same period, if a candidate would like to withdraw (an important functionality), then all the voters who had voted for that candidate should be allowed to then vote for another candidate. This would require tracking which candidate each voter voted for, which would be expensive in terms of space, and therefore in gas. Note that everyone in the population is an eligible voter, a candidate may also vote.

After the voting period, the election is closed and the address elected is calculated. This may entail using Chainlink VRF.

# TODO

-   Programmatically use Chainlink Automation
