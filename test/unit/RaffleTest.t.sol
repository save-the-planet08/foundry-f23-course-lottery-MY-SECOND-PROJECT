// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    //* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
         (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

    }
    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    ///////////////////////
    // enterRaffle ///////
    //////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true,false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////
    //CheckUpkeep////
    /////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp +interval+1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      raffle.performUpKeep("");

      (bool upkeepNeeded, ) = raffle.checkUpkeep("");
      assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      assert(!upkeepNeeded);

      
    }

    function testCheckUpkeepReturnsTrueWhenParamentersAreGood() public {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);

      (bool upkeepNeeded, ) = raffle.checkUpkeep("");
      assert(upkeepNeeded);
    }


    /////////////////////////////
    /// performUpkeep   /////////
    ///////////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);

      raffle.performUpKeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepisFalse() public {
      uint256 currentBalance = 0; 
      uint256 numPlayers = 0;
      uint raffleState = 0;
      vm.expectRevert(
        abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, 
        currentBalance, 
        numPlayers, 
        raffleState)
      );
      raffle.performUpKeep("");
    }

    modifier raffleEnteredAndTimePassed() {  
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      _;
    }
    

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestedId() 
        public 
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    /////////////////////////
    /// fulfillRandomWords //
    ////////////////////////

    modifier skipFork() {
      if (block.chainid != 31337) {
        return;
      }
      _;
    }


    function testFulfillRandomWordsWordsCanOnlyBeCalledAfterPerformUpkeep(
      uint256 randomRequestId
    ) 
    public 
    raffleEnteredAndTimePassed
    skipFork
    {
      vm.expectRevert("nonexistent request");
      VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
        randomRequestId,
        address(raffle)
      );
    }

    function testfulfillRandomWordsPicksAWinnerRestestsAndSendsMoney() 
    public 
    raffleEnteredAndTimePassed
    skipFork
    {
      uint256 additionalEntrants = 5;
      uint256 startingIndex = 1;
      for (
        uint256 i = startingIndex;
        i < startingIndex + additionalEntrants;
        i++
      ) {
        address player = address(uint160(i));
        hoax(player, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
      }
      uint256 prize = entranceFee * (additionalEntrants + 1);

      vm.recordLogs();
      raffle.performUpKeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];

      uint256 previousTimeStamp = raffle.getLastTimeStamp();

      VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
        uint256(requestId),
        address(raffle)
      );

      assert(uint256(raffle.getRaffleState()) == 0);
      assert(raffle.getRecentWinner() != address(0));
      assert(raffle.getLengthOfPlayers() == 0);
      assert(previousTimeStamp < raffle.getLastTimeStamp());
      assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
      
    }

}