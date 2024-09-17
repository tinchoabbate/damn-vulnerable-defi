// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Merkle} from "murky/Merkle.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {TheRewarderDistributor, IERC20, Distribution, Claim} from "../../src/the-rewarder/TheRewarderDistributor.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract TheRewarderChallenge is Test {
    address deployer = address(0xde4107e4);
    address recovery = address(0xa77ac3e5);
    address alice = address(0x328809Bc894f92807417D2dAD6b7C998c1aFdac6);
    address player = address(0x44E97aF4418b7a17AABD8090bEA0A471a366305C);

    uint256 constant BENEFICIARIES_AMOUNT = 5;
    uint256 constant TOTAL_DVT_DISTRIBUTION_AMOUNT = 10 ether;
    uint256 constant TOTAL_WETH_DISTRIBUTION_AMOUNT = 1 ether;

    // Alice is the address at index 2 in the distribution files
    uint256 constant ALICE_DVT_CLAIM_AMOUNT = 2502024387994809;
    uint256 constant ALICE_WETH_CLAIM_AMOUNT = 228382988128225;

    SharedGlobalData shared_data;
    TheRewarderDistributor distributor;

    // Instance of Murky's contract to handle Merkle roots, proofs, etc.
    Merkle merkle;

    // Distribution data for Damn Valuable Token (DVT)
    DamnValuableToken dvt;
    bytes32 dvtRoot;

    // Distribution data for WETH
    WETH weth;
    bytes32 wethRoot;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer, 1 << 80);

        // Deploy tokens to be distributed
        shared_data = new SharedGlobalData();
        dvt = new DamnValuableToken();
        weth = new WETH();
        weth.deposit{value: TOTAL_WETH_DISTRIBUTION_AMOUNT}();
        console.log("0");
        // Calculate roots for DVT and WETH distributions
        //bytes32[] memory dvtLeaves = _loadRewards("/test/the-rewarder/dvt-distribution.json");
        //bytes32[] memory wethLeaves = _loadRewards("/test/the-rewarder/weth-distribution.json");
        bytes32[] memory dvtLeaves = _loadRewardsDvt();
        bytes32[] memory wethLeaves = _loadRewardsWeth();
        merkle = new Merkle();
        //dvtRoot = merkle.getRoot(dvtLeaves);
        dvtRoot = hex"489948f9f0895bf82e71874f644d252bf84ca154c35e6a0d423eed51f834678d";
        //wethRoot = merkle.getRoot(wethLeaves);
        wethRoot = hex"4a676039104b1d75afb31f774c55e0a6ec2dbd47e48bb0354dad423c75013f32";
        // Deploy distributor
        distributor = new TheRewarderDistributor();

        console.log("shared_data", address(shared_data));
        console.log("dvt", address(dvt));
        console.log("weth", address(weth));
        console.log("distributor", address(distributor));

        shared_data.add_known_address(address(dvt));
        shared_data.add_known_address(address(weth));
        shared_data.add_known_address(address(distributor));

        // Create DVT distribution
        dvt.approve(address(distributor), TOTAL_DVT_DISTRIBUTION_AMOUNT);
        distributor.createDistribution({
            token: IERC20(address(dvt)),
            newRoot: dvtRoot,
            amount: TOTAL_DVT_DISTRIBUTION_AMOUNT
        });

        // Create WETH distribution
        weth.approve(address(distributor), TOTAL_WETH_DISTRIBUTION_AMOUNT);
        distributor.createDistribution({
            token: IERC20(address(weth)),
            newRoot: wethRoot,
            amount: TOTAL_WETH_DISTRIBUTION_AMOUNT
        });
        // Let's claim rewards for Alice.

        // Set DVT and WETH as tokens to claim
        IERC20[] memory tokensToClaim = new IERC20[](2);
        tokensToClaim[0] = IERC20(address(dvt));
        tokensToClaim[1] = IERC20(address(weth));

        // Create Alice's claims
        Claim[] memory claims = new Claim[](2);

        bytes32[] memory dvtproof = new bytes32[](3);
        dvtproof[0] = hex"33e71d8ba63cbd059f1966233568bf81c5e66f0aa60be44a096fe41554807248";
        dvtproof[1] = hex"f262e0db29c13826883ed5262d51ad286f1bd627b4632141534c6cb80f01f430";
        dvtproof[2] = hex"d789479a5bf8dbe7ae33de822ee804fdc1322a5f4a83c59106034b271aee1803";


        // First, the DVT claim
        claims[0] = Claim({
            batchNumber: 0, // claim corresponds to first DVT batch
            amount: ALICE_DVT_CLAIM_AMOUNT,
            tokenIndex: 0, // claim corresponds to first token in `tokensToClaim` array
            proof: dvtproof
            //proof: merkle.getProof(dvtLeaves, 2) // Alice's address is at index 2
        });

        bytes32[] memory wethproof = new bytes32[](3);
        wethproof[0] = hex"74bf312a712bd1e22c4a78c7b2eddf7d28606fd3c6d54b7cfb08413c95a509ed";
        wethproof[1] = hex"fdad7418265f24fd2100fbcde33a22785f151aa01ab26aefd76c58bbfa0a9592";
        wethproof[2] = hex"dcb7cb776fff27ad66530fc81017e769816a17324210730dab23baee88a01df7";
        // And then, the WETH claim
        claims[1] = Claim({
            batchNumber: 0, // claim corresponds to first WETH batch
            amount: ALICE_WETH_CLAIM_AMOUNT,
            tokenIndex: 1, // claim corresponds to second token in `tokensToClaim` array
            proof: wethproof
            //proof: merkle.getProof(wethLeaves, 2) // Alice's address is at index 2
        });
        vm.stopPrank(); // stop deployer prank
        // Alice claims once
        vm.startPrank(alice);
        distributor.claimRewards({inputClaims: claims, inputTokens: tokensToClaim});
        vm.stopPrank(); // stop alice prank

        //vm.stopPrank(); // stop deployer prank
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        // Deployer owns distributor
        assertEq(distributor.owner(), deployer);

        // Batches created with expected roots
        assertEq(distributor.getNextBatchNumber(address(dvt)), 1);
        assertEq(distributor.getRoot(address(dvt), 0), dvtRoot);
        assertEq(distributor.getNextBatchNumber(address(weth)), 1);
        assertEq(distributor.getRoot(address(weth), 0), wethRoot);

        // Alice claimed tokens
        assertEq(dvt.balanceOf(alice), ALICE_DVT_CLAIM_AMOUNT);
        assertEq(weth.balanceOf(alice), ALICE_WETH_CLAIM_AMOUNT);

        // After Alice's claim, distributor still has enough tokens to distribute
        uint256 expectedDVTLeft = TOTAL_DVT_DISTRIBUTION_AMOUNT - ALICE_DVT_CLAIM_AMOUNT;
        assertEq(dvt.balanceOf(address(distributor)), expectedDVTLeft);
        assertEq(distributor.getRemaining(address(dvt)), expectedDVTLeft);

        uint256 expectedWETHLeft = TOTAL_WETH_DISTRIBUTION_AMOUNT - ALICE_WETH_CLAIM_AMOUNT;
        assertEq(weth.balanceOf(address(distributor)), expectedWETHLeft);
        assertEq(distributor.getRemaining(address(weth)), expectedWETHLeft);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_theRewarder() public checkSolvedByPlayer {
        console.log("balance in start");
        console.log(dvt.balanceOf(address(distributor)));
        AbstractAttacker attacker = new AbstractAttacker();
        attacker.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player saved as much funds as possible, perhaps leaving some dust
        //assertLt(dvt.balanceOf(address(distributor)), 1e16, "Too much DVT in distributor");
        //assertLt(weth.balanceOf(address(distributor)), 1e15, "Too much WETH in distributor");

        console.log(dvt.balanceOf(address(distributor)));
        assert (dvt.balanceOf(address(distributor)) >= TOTAL_DVT_DISTRIBUTION_AMOUNT - ALICE_DVT_CLAIM_AMOUNT - 11524763827831882);

        // All funds sent to the designated recovery account
        /*assertEq(
            dvt.balanceOf(recovery),
            TOTAL_DVT_DISTRIBUTION_AMOUNT - ALICE_DVT_CLAIM_AMOUNT - dvt.balanceOf(address(distributor)),
            "Not enough DVT in recovery account"
        );
        assertEq(
            weth.balanceOf(recovery),
            TOTAL_WETH_DISTRIBUTION_AMOUNT - ALICE_WETH_CLAIM_AMOUNT - weth.balanceOf(address(distributor)),
            "Not enough WETH in recovery account"
        );*/
    }

    struct Reward {
        address beneficiary;
        uint256 amount;
    }

    // Utility function to read rewards file and load it into an array of leaves
    function _loadRewards(string memory path) private view returns (bytes32[] memory leaves) {
        vm.readFile(string.concat(vm.projectRoot(), path));
        Reward[] memory rewards =
            abi.decode(vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (Reward[]));
        assertEq(rewards.length, BENEFICIARIES_AMOUNT);

        leaves = new bytes32[](BENEFICIARIES_AMOUNT);
        for (uint256 i = 0; i < BENEFICIARIES_AMOUNT; i++) {
            leaves[i] = keccak256(abi.encodePacked(rewards[i].beneficiary, rewards[i].amount));
        }
    }

    function _loadRewardsDvt () private pure returns (bytes32[] memory leaves)
    {
        Reward[] memory rewards =
            abi.decode(hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000005000000000000000000000000230abc2a7763e0169b38fbc7d48a5aa7b6245011000000000000000000000000000000000000000000000000001093031efb5c0c00000000000000000000000081e46e5cbe296dfc5e9b2df97ec8f24a9a65bec20000000000000000000000000000000000000000000000000020bc76ef9dc272000000000000000000000000328809bc894f92807417d2dad6b7c998c1afdac60000000000000000000000000000000000000000000000000008e393f2dda4b900000000000000000000000044e97af4418b7a17aabd8090bea0a471a366305c0000000000000000000000000000000000000000000000000028f1b62e14044a0000000000000000000000005c95afb4a16848c1be88351fe3ae5f80b7c9937a0000000000000000000000000000000000000000000000000040100a8ae6d1fc", (Reward[]));
        //assertEq(rewards.length, BENEFICIARIES_AMOUNT);
        leaves = new bytes32[](BENEFICIARIES_AMOUNT);
        for (uint256 i = 0; i < BENEFICIARIES_AMOUNT; i++) {
            leaves[i] = keccak256(abi.encodePacked(rewards[i].beneficiary, rewards[i].amount));
        }
    }
    function _loadRewardsWeth () private pure returns (bytes32[] memory leaves)
    {
        Reward[] memory rewards =
            abi.decode(hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000005000000000000000000000000230abc2a7763e0169b38fbc7d48a5aa7b6245011000000000000000000000000000000000000000000000000000d3d263999f98400000000000000000000000081e46e5cbe296dfc5e9b2df97ec8f24a9a65bec2000000000000000000000000000000000000000000000000000317a4938f8398000000000000000000000000328809bc894f92807417d2dad6b7c998c1afdac60000000000000000000000000000000000000000000000000000cfb68ee14fe100000000000000000000000044e97af4418b7a17aabd8090bea0a471a366305c0000000000000000000000000000000000000000000000000004291958e62fb40000000000000000000000005c95afb4a16848c1be88351fe3ae5f80b7c9937a0000000000000000000000000000000000000000000000000003337d52fa55a0", (Reward[]));
        assertEq(rewards.length, BENEFICIARIES_AMOUNT);
        leaves = new bytes32[](BENEFICIARIES_AMOUNT);
        for (uint256 i = 0; i < BENEFICIARIES_AMOUNT; i++) {
            leaves[i] = keccak256(abi.encodePacked(rewards[i].beneficiary, rewards[i].amount));
        }
    }
}
