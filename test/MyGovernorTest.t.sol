// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");

    address[] executors;
    address[] proposers;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour after a vote pass
    uint256 public constant VOTING_DELAY = 1; // how many blocks to wait before voting on the proposal
    uint256 public constant VOTING_PERIOD = 50400;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposersRole = timelock.PROPOSER_ROLE();
        bytes32 executorsRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposersRole, address(governor));
        timelock.grantRole(executorsRole, address(0));
        timelock.grantRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGoveranceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("Proposal State:", uint256(governor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // 2. VOTE
        string memory reason = "why not?";

        uint8 voteway = 1; // voting YES
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteway, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3 Queue TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. EXECUTE
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box value:", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}
