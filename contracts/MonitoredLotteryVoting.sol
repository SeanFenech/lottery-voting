pragma solidity ^0.8.7;
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract LARVA_CLCompatableLotteryVoting is VRFConsumerBaseV2Plus {
    modifier LARVA_Constructor() {
        _;
        {
            LARVA_EnableContract();
        }
    }
    modifier LARVA_DEA_2_handle_after_assignment_s_votes() {
        _;
        if ((LARVA_STATE_2 == 0) && (s_votes[_index] < LARVA_previous_s_votes)) {
            LARVA_STATE_2 = 2;
            LARVA_reparation();
        }
    }
    modifier LARVA_DEA_2_handle_after_openVotingPeriod__no_parameters() {
        _;
        if ((LARVA_STATE_2 == 0)) {
            LARVA_STATE_2 = 1;
        }
    }
    modifier LARVA_DEA_2_handle_after_closeElection__no_parameters() {
        _;
        if ((LARVA_STATE_2 == 1)) {
            LARVA_STATE_2 = 0;
        }
    }
    modifier LARVA_DEA_1_handle_after_assignment_s_candidates() {
        _;
        if ((LARVA_STATE_1 == 0) && (s_candidates[_index] != LARVA_previous_s_candidates)) {
            LARVA_STATE_1 = 2;
            LARVA_reparation();
        }
    }
    modifier LARVA_DEA_1_handle_after_openVotingPeriod__no_parameters() {
        _;
        if ((LARVA_STATE_1 == 1)) {
            LARVA_STATE_1 = 0;
        }
    }
    modifier LARVA_DEA_1_handle_after_openElection__no_parameters() {
        _;
        if ((LARVA_STATE_1 == 0)) {
            LARVA_STATE_1 = 1;
        }
    }
    int8 LARVA_STATE_1 = 0;
    int8 LARVA_STATE_2 = 0;

    function LARVA_set_s_candidates_pre(
        int _index,
        address _s_candidates_value
    ) internal LARVA_DEA_1_handle_after_assignment_s_candidates returns (address) {
        LARVA_previous_s_candidates_value = s_candidates;
        s_candidates[_index] = _s_candidates_value;
        return LARVA_previous_s_candidates;
    }

    function LARVA_set_s_candidates_post(
        int _index,
        address _s_candidates_value
    ) internal LARVA_DEA_1_handle_after_assignment_s_candidates returns (address) {
        LARVA_previous_s_candidates_value = s_candidates;
        s_candidates[_index] = _s_candidates_value;
        return s_candidates;
    }

    address private LARVA_previous_s_candidates;

    function LARVA_set_s_votes_pre(
        bytes32 _index,
        uint256 _s_votes_value
    ) internal LARVA_DEA_2_handle_after_assignment_s_votes returns (uint256) {
        LARVA_previous_s_votes_value = s_votes;
        s_votes[_index] = _s_votes_value;
        return LARVA_previous_s_votes;
    }

    function LARVA_set_s_votes_post(
        bytes32 _index,
        uint256 _s_votes_value
    ) internal LARVA_DEA_2_handle_after_assignment_s_votes returns (uint256) {
        LARVA_previous_s_votes_value = s_votes;
        s_votes[_index] = _s_votes_value;
        return s_votes;
    }

    uint256 private LARVA_previous_s_votes;

    function LARVA_selfdestruct(address payable _to) internal {
        selfdestruct(_to);
    }

    function LARVA_transfer(address payable _to, uint amount) internal {
        _to.transfer(amount);
    }

    function LARVA_reparation() private {
        revert();
    }

    enum LARVA_STATUS {
        RUNNING,
        STOPPED
    }

    function LARVA_EnableContract() private {
        LARVA_Status = LARVA_STATUS.RUNNING;
    }

    function LARVA_DisableContract() private {
        LARVA_Status = LARVA_STATUS.STOPPED;
    }

    LARVA_STATUS private LARVA_Status = LARVA_STATUS.STOPPED;
    modifier LARVA_ContractIsEnabled() {
        require(LARVA_Status == LARVA_STATUS.RUNNING);
        _;
    }
    enum ElectionState {
        CLOSED,
        CANDIDATE_PERIOD,
        VOTING_PERIOD,
        CALCULATING
    }
    mapping(address => bool) private s_population;
    mapping(bytes32 => bool) private s_election;
    address[] private s_candidates;
    mapping(bytes32 => uint256) private s_votes;
    uint256 private i_electionFrequency;
    uint256 private i_candidateInterval;
    uint256 private i_voterInterval;
    address private s_elected;
    uint256 private s_electionNumber = 0;
    ElectionState private s_electionState;
    uint256 private s_lastElectionTime;
    uint256 private s_lastVotingTime;
    IVRFCoordinatorV2Plus private i_vrfCoordinator;
    bytes32 private i_gasLane;
    uint256 private i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    modifier onlyElected() {
        require(msg.sender == s_elected, "Access Denied");
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
    ) LARVA_Constructor VRFConsumerBaseV2Plus(vrfCoordinatorV2Plus) {
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

    function openElection()
        public
        LARVA_DEA_1_handle_after_openElection__no_parameters
        LARVA_ContractIsEnabled
    {
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.CLOSED, "Outside interval");
        require((block.timestamp - s_lastElectionTime) > i_electionFrequency, "Too Early");
        s_electionState = ElectionState.CANDIDATE_PERIOD;
        s_lastElectionTime = block.timestamp;
    }

    function openVotingPeriod()
        public
        LARVA_DEA_2_handle_after_openVotingPeriod__no_parameters
        LARVA_DEA_1_handle_after_openVotingPeriod__no_parameters
        LARVA_ContractIsEnabled
    {
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.CANDIDATE_PERIOD, "Outside interval");
        require(((block.timestamp - s_lastElectionTime) > i_candidateInterval), "Too Early");
        s_electionState = ElectionState.VOTING_PERIOD;
        s_lastVotingTime = block.timestamp;
    }

    function closeElection()
        public
        LARVA_DEA_2_handle_after_closeElection__no_parameters
        LARVA_ContractIsEnabled
    {
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.VOTING_PERIOD, "Outside interval");
        require((block.timestamp - s_lastVotingTime) > i_voterInterval, "Too Early");
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

    function fulfillRandomWords(
        uint256,
        uint256[] memory _randomWords
    ) internal override LARVA_ContractIsEnabled {
        calculateElection(_randomWords[0]);
    }

    function calculateElection(uint256 random) internal LARVA_ContractIsEnabled {
        address[] memory candidates = s_candidates;
        uint256 length = candidates.length;
        uint256 totalVoters;
        int256 firstWithVotes = -1;
        bool votesExist = false;
        uint256 numVotes = 0;
        for (uint256 i = 0; i < length; i++) {
            numVotes = getVotes(s_electionNumber, candidates[i]);
            totalVoters +=
                (totalVoters) +
                ((totalVoters) + ((totalVoters) + ((totalVoters) + (numVotes))));
            if ((numVotes > 0) && !votesExist) {
                votesExist = true;
                firstWithVotes = int256(i);
            }
        }
        if (!votesExist) {
            elect(candidates[random % length]);
            return;
        }
        if (totalVoters == 1) {
            elect(candidates[uint256(firstWithVotes)]);
            return;
        }
        uint256 result = random % totalVoters;
        uint256 accumulation = 0;
        for (uint256 i = 0; i < length; i++) {
            accumulation +=
                (accumulation) +
                ((accumulation) +
                    ((accumulation) +
                        ((accumulation) + (getVotes(s_electionNumber, candidates[i])))));
            if (result < accumulation) {
                elect(candidates[i]);
                return;
            }
            s_candidates.pop();
        }
    }

    function elect(address a) internal LARVA_ContractIsEnabled {
        s_electionNumber++;
        s_elected = a;
        s_electionState = ElectionState.CLOSED;
    }

    function run() public LARVA_ContractIsEnabled {
        require(s_population[msg.sender], "Not part of population");
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.CANDIDATE_PERIOD, "Outside interval");
        address[] memory candidates = s_candidates;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == msg.sender) {
                revert("Already Candidate");
            }
        }
        s_candidates.push(msg.sender);
    }

    function withdraw() public LARVA_ContractIsEnabled {
        require(s_population[msg.sender], "Not part of population");
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.CANDIDATE_PERIOD, "Outside interval");
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
        require(alreadyCandidate, "Not Candidate");
        candidates[index] = candidates[length - 1];
        LARVA_set_s_candidates_post(candidates);
        s_candidates.pop();
    }

    function vote(address chosenCandidate) public LARVA_ContractIsEnabled {
        require(s_population[msg.sender], "Not part of population");
        ElectionState electionState = s_electionState;
        require(electionState == ElectionState.VOTING_PERIOD, "Outside interval");
        uint256 eNum = s_electionNumber;
        require(!getElection(eNum, msg.sender), "Already Voted");
        address[] memory candidates = s_candidates;
        bool validCandidate = false;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == chosenCandidate) {
                validCandidate = true;
                break;
            }
        }
        require(validCandidate, "Invalid Candidate");
        setElection(eNum, msg.sender);
        incrementVotes(eNum, chosenCandidate);
    }

    function getElection(
        uint256 electionNumber,
        address voter
    ) internal view LARVA_ContractIsEnabled returns (bool) {
        return s_election[keccak256(abi.encodePacked(electionNumber, voter))];
    }

    function setElection(uint256 electionNumber, address voter) internal LARVA_ContractIsEnabled {
        s_election[keccak256(abi.encodePacked(electionNumber, voter))] = true;
    }

    function getVotes(
        uint256 electionNumber,
        address candidate
    ) internal view LARVA_ContractIsEnabled returns (uint256) {
        return s_votes[keccak256(abi.encodePacked(electionNumber, candidate))];
    }

    function incrementVotes(
        uint256 electionNumber,
        address candidate
    ) internal LARVA_ContractIsEnabled {
        LARVA_set_s_votes_post(
            keccak256(abi.encodePacked(electionNumber, candidate)),
            getVotes(electionNumber, candidate) + 1
        );
    }

    function desiredFunctionalityForElected() public LARVA_ContractIsEnabled onlyElected {}

    function getState() public view LARVA_ContractIsEnabled returns (ElectionState) {
        return s_electionState;
    }

    function getCandidates() public view LARVA_ContractIsEnabled returns (address[] memory) {
        return s_candidates;
    }

    function getElectionNumber() public view LARVA_ContractIsEnabled returns (uint256) {
        return s_electionNumber;
    }

    function getPopulationMember(address a) public view LARVA_ContractIsEnabled returns (bool) {
        return s_population[a];
    }

    function getElected() public view LARVA_ContractIsEnabled returns (address) {
        return s_elected;
    }

    function getCurrentElection(address a) public view LARVA_ContractIsEnabled returns (bool) {
        return getElection(s_electionNumber, a);
    }

    function getCurrentVotes(address a) public view LARVA_ContractIsEnabled returns (uint256) {
        return getVotes(s_electionNumber, a);
    }

    function getTimingInfo() public view LARVA_ContractIsEnabled returns (uint256[5] memory) {
        return [
            i_electionFrequency,
            i_candidateInterval,
            i_voterInterval,
            s_lastElectionTime,
            s_lastVotingTime
        ];
    }
}
