// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "../src/CreativeFlowStateMachine.sol";
import "../src/CannaSapiens.sol";

contract CreativeFlowStateMachineTest is Test {
    CreativeFlowStateMachine factory;

    address owner = address(0xABCD);
    address user = address(0xEF01);

    // mockRoot is the merkle root. We'll treat it as a single-leaf tree equal to `address(this)`.
    // For a single-leaf merkle tree, the root = leaf, and we do not need any intermediate proofs.
    bytes32 mockRoot = keccak256(abi.encodePacked(address(this)));

    function setUp() public {
        vm.prank(owner);
        factory = new CreativeFlowStateMachine();

        // Set phase 1 price and merkle root
        vm.prank(owner);
        factory.setPrice(CreativeFlowStateMachine.Phase.PHASE_1, 0.01 ether);

        vm.prank(owner);
        factory.setMerkleRoot(CreativeFlowStateMachine.Phase.PHASE_1, mockRoot);

        vm.prank(owner);
        factory.setPhase(CreativeFlowStateMachine.Phase.PHASE_1);
    }

    function testMintAndReveal() public {
        vm.deal(user, 1 ether);
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.expectRevert(CreativeFlowStateMachine.NotWhitelisted.selector);
        vm.prank(user);
        factory.mint{value: 0.01 ether}("TestNFT", "TNF", emptyProof, keccak256("salt"));

        // Mint from whitelisted address (this)
        vm.deal(address(this), 1 ether);
        vm.prank(address(this));
        factory.mint{value: 0.01 ether}("TestNFT", "TNF", emptyProof, keccak256("salt"));

        address childAddress = factory.contracts(1);
        CannaSapiens child = CannaSapiens(childAddress);

        vm.prank(owner);
        factory.revealSupply(1);
        uint256 maxSupply = child.maxSupply();
        assertTrue(maxSupply > 0 && maxSupply <= 6666, "Invalid max supply");

        vm.prank(owner);
        factory.setChildContractPaused(1, false);

        // Mint to `user` instead of `address(this)`
        vm.prank(address(this));
        child.mint(user);
        assertEq(child.currentTokenId(), 1, "Token not minted");
    }


    function testPauseAll() public {
        // Mint a contract from whitelisted address
        vm.deal(address(this), 1 ether);
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.prank(address(this));
        factory.mint{value: 0.01 ether}("TestNFT", "TNF", emptyProof, keccak256("salt"));

        address childAddress = factory.contracts(1);
        CannaSapiens child = CannaSapiens(childAddress);

        // Reveal supply and unpause child
        vm.prank(owner);
        factory.revealSupply(1);

        vm.prank(owner);
        factory.setChildContractPaused(1, false);

        // Pause all contracts
        vm.prank(owner);
        factory.pauseAllContracts(true);
        assertTrue(child.paused(), "Child contract not paused");
    }

    function testSetBaseURI() public {
        // Mint a contract from whitelisted address
        vm.deal(address(this), 1 ether);
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.prank(address(this));
        factory.mint{value: 0.01 ether}("TestNFT", "TNF", emptyProof, keccak256("salt"));

        address childAddress = factory.contracts(1);
        CannaSapiens child = CannaSapiens(childAddress);

        // Reveal supply
        vm.prank(owner);
        factory.revealSupply(1);

        // Unpause and set base URI
        vm.prank(owner);
        factory.setChildContractPaused(1, false);

        vm.prank(owner);
        factory.setChildBaseURI(1, "https://api.example.com/metadata/");

        // Mint a token
        vm.prank(address(this));
        child.mint(user);

        string memory uri = child.tokenURI(1);
        assertEq(uri, "https://api.example.com/metadata/1", "Incorrect token URI");
    }
}
