// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

error LotteryVoting__NotPartOfPopulation();
error LotteryVoting__AlreadyCandidate();
error LotteryVoting__NotCandidate();
error LotteryVoting__AlreadyVoted();
error LotteryVoting__InvalidCandidate();
error LotteryVoting__TooEarly();
error LotteryVoting__NotElected();
error LotteryVoting__OutsideInterval(uint256 electionState);

contract LotteryVoting is VRFConsumerBaseV2Plus {
    enum ElectionState {
        CLOSED,
        CANDIDATE_PERIOD,
        VOTING_PERIOD,
        CALCULATING
    }

    mapping(address member => bool) private s_population;
    mapping(bytes32 voter => bool) private s_election;
    address[] private s_candidates;
    mapping(bytes32 candidate => uint256) private s_votes;

    uint256 private immutable i_electionFrequency;
    uint256 private immutable i_candidateInterval;
    uint256 private immutable i_voterInterval;

    address private s_elected;
    uint256 private s_electionNumber = 0;
    ElectionState private s_electionState;
    uint256 private s_lastElectionTime;
    uint256 private s_lastVotingTime;

    IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    modifier onlyElected() {
        //For functions which only the elected should have access to.
        if (msg.sender != s_elected) revert LotteryVoting__NotElected();
        _;
    }

    event ErrorDetected();

    constructor(
        address[] memory pop,
        address initialElected,
        uint256 electionFrequency,
        uint256 candidateInterval,
        uint256 voterInterval,
        address vrfCoordinatorV2Plus,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2Plus) {
        for (uint256 i = 0; i < pop.length; i++) {
            s_population[pop[i]] = true;
        }
        i_electionFrequency = electionFrequency;
        i_candidateInterval = candidateInterval;
        i_voterInterval = voterInterval;
        s_elected = initialElected;
        s_electionState = ElectionState.CLOSED;
        i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinatorV2Plus);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
    }

    ///////////////////////////////////////////////////////////////////////////
    //Functions to be called automatically every set period of time, using Chainlink Automation for example.

    function openElection() public {
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.CLOSED)
            revert LotteryVoting__OutsideInterval(uint256(electionState));
        if ((block.timestamp - s_lastElectionTime) < i_electionFrequency)
            revert LotteryVoting__TooEarly();

        s_electionState = ElectionState.CANDIDATE_PERIOD;
        s_lastElectionTime = block.timestamp;
    }

    function openVotingPeriod() public {
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.CANDIDATE_PERIOD)
            revert LotteryVoting__OutsideInterval(uint256(electionState));
        if ((block.timestamp - s_lastElectionTime) < i_candidateInterval)
            revert LotteryVoting__TooEarly();

        s_electionState = ElectionState.VOTING_PERIOD;
        s_lastVotingTime = block.timestamp;
    }

    function closeElection() public {
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.VOTING_PERIOD)
            revert LotteryVoting__OutsideInterval(uint256(electionState));
        if ((block.timestamp - s_lastVotingTime) < i_voterInterval)
            revert LotteryVoting__TooEarly();

        s_electionState = ElectionState.CALCULATING;

        if (s_candidates.length == 0) {
            elect(s_elected);
            return;
        }
        if (s_candidates.length == 1) {
            elect(s_candidates[0]);
            s_candidates.pop();
            return;
        }

        // Random number requested from Chainlink VRF, which will be passed to function with logic to calculate election winner.
        i_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callBackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    //Chainlink VRF will call this function.
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        calculateElection(_randomWords[0]);
    }

    function calculateElection(uint256 random) internal {
        address[] memory candidates = s_candidates;
        uint256 length = candidates.length;
        uint256 totalVoters;

        int256 firstWithVotes = -1;
        bool votesExist = false;
        uint256 numVotes = 0;
        for (uint256 i = 0; i < length; i++) {
            numVotes = getVotes(s_electionNumber, candidates[i]);
            totalVoters += numVotes;
            if ((numVotes > 0) && !votesExist) {
                votesExist = true;
                firstWithVotes = int256(i);
            }
        }
        if (!votesExist) {
            //If no votes were made, then it is random.
            elect(candidates[random % length]);
            return;
        }
        if (totalVoters == 1) {
            //If only one vote was made, the candidate has 100% chance.
            elect(candidates[uint256(firstWithVotes)]);
            return;
        }

        uint256 result = random % totalVoters;
        uint256 accumulation = 0;

        for (uint256 i = 0; i < length; i++) {
            accumulation += getVotes(s_electionNumber, candidates[i]);
            if (result < accumulation) {
                elect(candidates[i]);
                return;
            }
            s_candidates.pop();
        }
    }

    function elect(address a) internal {
        s_electionNumber++;
        s_elected = a;
        s_electionState = ElectionState.CLOSED;
    }

    ///////////////////////////////////////////////////////////////////////////
    //Functions called by population

    function run() public {
        if (!s_population[msg.sender]) revert LotteryVoting__NotPartOfPopulation();
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.CANDIDATE_PERIOD)
            revert LotteryVoting__OutsideInterval(uint256(electionState));

        address[] memory candidates = s_candidates; //To save gas by reading once.
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == msg.sender) {
                revert LotteryVoting__AlreadyCandidate();
            }
        }
        s_candidates.push(msg.sender);
    }

    function withdraw() public {
        if (!s_population[msg.sender]) revert LotteryVoting__NotPartOfPopulation();
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.CANDIDATE_PERIOD)
            revert LotteryVoting__OutsideInterval(uint256(electionState));
        address[] memory candidates = s_candidates;
        bool alreadyCandidate = false;

        uint256 index;
        uint256 length = candidates.length;
        for (uint i = 0; i < length; i++) {
            if (candidates[i] == msg.sender) {
                alreadyCandidate = true;
                index = i;
                break;
            }
        }
        if (!alreadyCandidate) revert LotteryVoting__NotCandidate();

        candidates[index] = candidates[length - 1];
        s_candidates = candidates;
        s_candidates.pop();
    }

    function vote(address chosenCandidate) public {
        if (!s_population[msg.sender]) revert LotteryVoting__NotPartOfPopulation();
        ElectionState electionState = s_electionState;
        if (electionState != ElectionState.VOTING_PERIOD)
            revert LotteryVoting__OutsideInterval(uint256(electionState));

        uint256 eNum = s_electionNumber;
        if (getElection(eNum, msg.sender)) revert LotteryVoting__AlreadyVoted();

        address[] memory candidates = s_candidates;
        bool validCandidate = false;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == chosenCandidate) {
                validCandidate = true;
                break;
            }
        }
        if (!validCandidate) revert LotteryVoting__InvalidCandidate();

        setElection(eNum, msg.sender);
        incrementVotes(eNum, chosenCandidate);
    }

    ///////////////////////////////////////////////////////////////////////////
    //Utility functions

    function getElection(uint256 electionNumber, address voter) internal view returns (bool) {
        return s_election[keccak256(abi.encodePacked(electionNumber, voter))];
    }

    function setElection(uint256 electionNumber, address voter) internal {
        s_election[keccak256(abi.encodePacked(electionNumber, voter))] = true;
    }

    function getVotes(uint256 electionNumber, address candidate) internal view returns (uint256) {
        return s_votes[keccak256(abi.encodePacked(electionNumber, candidate))];
    }

    function incrementVotes(uint256 electionNumber, address candidate) internal {
        s_votes[keccak256(abi.encodePacked(electionNumber, candidate))] =
            getVotes(electionNumber, candidate) +
            1;
    }

    ///////////////////////////////////////////////////////////////////////////
    function desiredFunctionalityForElected() public onlyElected {
        // Desired functionality in here, and in other similar functions.
    }

    ///////////////////////////////////////////////////////////////////////////
    //Getters and Setters

    function getState() public view returns (ElectionState) {
        return s_electionState;
    }

    function getCandidates() public view returns (address[] memory) {
        return s_candidates;
    }

    function getElectionNumber() public view returns (uint256) {
        return s_electionNumber;
    }

    function getPopulationMember(address a) public view returns (bool) {
        return s_population[a];
    }

    function getElected() public view returns (address) {
        return s_elected;
    }

    function getCurrentElection(address a) public view returns (bool) {
        return getElection(s_electionNumber, a);
    }

    function getCurrentVotes(address a) public view returns (uint256) {
        return getVotes(s_electionNumber, a);
    }

    function getTimingInfo() public view returns (uint256[5] memory) {
        return [
            i_electionFrequency,
            i_candidateInterval,
            i_voterInterval,
            s_lastElectionTime,
            s_lastVotingTime
        ];
    }
}
