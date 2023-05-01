// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* ########################## */
/* ### TIMELOCK CONSTANTS ### */
/* ########################## */

// keccak256("ADMIN_ROLE");
bytes32 constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

// keccak256("PROPOSER_ROLE");
bytes32 constant PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;

uint256 constant MAX_TARGETS = 256;
uint256 constant MIN_TARGETS = 0;
uint256 constant MAX_DELAY = 14 days;

/* ####################### */
/* ### VAULT CONSTANTS ### */
/* ####################### */

uint256 constant WITHDRAWAL_LIMIT = 1 ether;
uint256 constant WAITING_PERIOD = 15 days;
