// SPDX-License-Identifier: MIT  
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
    
contract LotteryV2 is KeeperCompatibleInterface, VRFConsumerBase, ConfirmedOwner{

    //Price of ticket -- $2 in tokens / Alternative: 100000 Tokens
    //Five Lucky numbers 
    // Just 2 numbers on your ticket    -- 3% prize pool 
    // Just 3 numbers on your ticket    -- 7% prize pool
    // Just 4 numbers on your ticket    -- 15% prize pool
    // 5 numbers on your ticket    -- 25% prize pool
    // 50% to the burn pool


    //Store User Data
    //Like Past Lotteries
    //Time Tickets ws

    uint256 internal lotteryStartTimestamp;
    uint256 internal lotteryID;
    uint256 internal immutable lotteryInterval = 2 * 1 days;
    uint256 internal immutable resetInterval = 2 * 1 hours; 
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 internal ticketPrice;

    address internal LISH = 0x94ba851c8b70eA0BB5eB46217ADd5724541D1150;

    enum State {
        IDLE,
        ACTIVE,
        REBOOT
    }

    struct LotteryStruct{
        uint256 ID;                             //Lottery ID
        address payable winner;               // Winner address
        uint256 noOfTicketsSold;                   // Tickets sold
        uint256[] winningTicket;
        uint256 amountInLottery;
        mapping(address => uint256[]) ticketOwner; //a mapping that maps the ticketsID to their owners
    }

    //mapping of requestIDs to eachLotteryID
    mapping (uint256 => bytes32) internal requestsMap;
     
    mapping (uint256 => LotteryStruct) internal lotteries;

    State public currentState = State.IDLE;
    // Governs the contract flow, as the three lotteries are ran parallel to each other.

    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee, uint256 _ticketPrice)
        VRFConsumerBase(_vrfCoordinator, _link) ConfirmedOwner(msg.sender)
    {
        keyHash = _keyHash;
        fee = _fee * (10 ** 17);
        ticketPrice = _ticketPrice * (10 ** 18);
    }

    function startLottery()
        internal
        inState(State.IDLE)
    {
        //setting Lottery duration
        lotteryStartTimestamp = block.timestamp;

        currentState = State.ACTIVE;

        // creating Lottery session
        LotteryStruct storage _lottery = lotteries[lotteryID];
        _lottery.ID = lotteryID;

        lotteryID++;
    }

    function viewLottery(uint256 _lotteryID) public view returns(
        uint256 ID,                      
        address payable winner,              
        uint256 noOfTicketsSold,                 
        uint256[] memory winningTicket,
        uint256 amountInLottery
    ){
        LotteryStruct storage _lottery = lotteries[_lotteryID];
        return(
            _lottery.ID,
            _lottery.winner,
            _lottery.noOfTicketsSold,
            _lottery.winningTicket,
            _lottery.amountInLottery
        );
    }

    function buyTicket(uint256 _noOfTickets, uint256[] memory _tickets) public payable inState(State.ACTIVE){
        require(IERC20(LISH).transferFrom(msg.sender, address(this), (_noOfTickets*ticketPrice)), "Transfer failed");
        assignTickets(_noOfTickets, _tickets);
    }

    function assignTickets(uint256 _noOfTickets, uint256[] memory _tickets) internal {
        LotteryStruct storage _lottery = lotteries[lotteryID];

        for(uint n = 0 ; n < _noOfTickets; n++){
            _lottery.ticketOwner[msg.sender].push(_tickets[n]);
        }
        _lottery.noOfTicketsSold += _noOfTickets;
        _lottery.amountInLottery += (_noOfTickets*ticketPrice);

    }

    function getWinningTickets() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        requestsMap[lotteryID] = requestId;
        LotteryStruct storage _lottery = lotteries[lotteryID];
        _lottery.winningTicket = expand(randomness);
        currentState = State.REBOOT;
    }

    function expand(uint256 randomValue) internal pure returns (uint256[] memory winningTickets) {
        winningTickets = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            winningTickets[i] = (uint256(keccak256(abi.encode(randomValue, i))) % 10) + 1;
        }
        return winningTickets;
    }

    function payoutWinner() internal {
        currentState = State.IDLE;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if(((block.timestamp - lotteryStartTimestamp) > lotteryInterval) && (currentState == State.ACTIVE)){
            upkeepNeeded = true;
            performData = abi.encode(1);
        }
        if(currentState == State.REBOOT){
            upkeepNeeded = true;
            performData = abi.encode(2);
        }
        if((block.timestamp - lotteryStartTimestamp) > (lotteryInterval + resetInterval) && (currentState == State.IDLE)){
            upkeepNeeded = true;
            performData = abi.encode(3);
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        int comment = abi.decode(performData, (int));
        if (comment == 1){
            getWinningTickets();
        }else if (comment == 2){
            payoutWinner();
        }else if (comment == 3){
            startLottery();
        }    
    }

    function checkLinkBalance() public view returns(uint256){
        return(LINK.balanceOf(address(this)));
    }


    modifier inState(State state) {
        require(state == currentState, "current state does not allow this");
        _;
    }

    modifier estimateAmountToBeSpent(uint256 _noOfTickets, uint256 _amount) {
        require((_noOfTickets*ticketPrice) == _amount, "Insufficient Funds");
        _;
    }
}
