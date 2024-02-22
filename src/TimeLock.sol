// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay
    // Proposers
    // executors

    constructor(uint256 minDelay, address[] memory propers, address[] memory executors)
        TimelockController(minDelay, propers, executors, msg.sender)
    {}
}
