// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract TestInteractions is Test {
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;
    HelperConfig helperConfig;
    VRFCoordinatorV2Mock vrfCoordinator;
    LinkToken linkToken;
    uint256 deployerKey;
    uint64 subId;

    function setUp() public {
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
        helperConfig = new HelperConfig();
        
        // Set up the configuration
        (,, address vrfCoordinatorAddress, , , , address linkTokenAddress, uint256 key) = helperConfig.activeNetworkConfig();
        
        vrfCoordinator = VRFCoordinatorV2Mock(vrfCoordinatorAddress);
        linkToken = LinkToken(linkTokenAddress);
        deployerKey = key;

        subId = createSubscription.createSubscription(vrfCoordinatorAddress, deployerKey);
    }

    function testCreateSubscriptionUsingConfig() public {
        uint64 subscriptionId = createSubscription.createSubscriptionUsingConfig();
        assert(subscriptionId > 0);
    }

    //* function testFundSubscriptionUsingConfig() public {
        //fundSubscription.fundSubscriptionUsingConfing();
        //(, , ,uint96 balance, ) = vrfCoordinator.getSubscription(subId);
      //  assert(balance == FundSubscription.FUND_AMOUNT);
    //}

    /*function testAddConsumerUsingConfig() public {
        // Mock Raffle contract address
        address raffle = address(0x12345);

        addConsumer.addConsumerUsingConfig(raffle);
        address[] memory consumers = vrfCoordinator.getConsumers(subId);
        bool consumerExists = false;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == raffle) {
                consumerExists = true;
                break;
            }
        }
        assert(consumerExists);
    }*/
}
