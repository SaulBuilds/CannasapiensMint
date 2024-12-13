// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "../src/CannaSapiens.sol";

contract CannaSapiensTest is Test {
    CannaSapiens nft;
    address factory = address(0x1234);
    address user = address(0xEF01);

    function setUp() public {
        nft = new CannaSapiens("Canna", "CNS", factory);
    }

    function testInitialPauseState() public view {
        assertTrue(nft.paused(), "Should be paused initially");
    }

    function testSetMaxSupply() public {
        vm.prank(factory);
        nft.setMaxSupply(100);
        assertEq(nft.maxSupply(), 100);
    }

    function testMintWhenNotPaused() public {
        vm.prank(factory);
        nft.setMaxSupply(100);

        vm.prank(factory);
        nft.setPaused(false);

        vm.prank(user);
        nft.mint(user);
        assertEq(nft.currentTokenId(), 1);
    }

    function testBaseURIAndTokenURI() public {
        vm.prank(factory);
        nft.setMaxSupply(10);

        vm.prank(factory);
        nft.setPaused(false);

        vm.prank(factory);
        nft.setBaseURI("ipfs://collection_base/");

        vm.prank(user);
        nft.mint(user);

        string memory uri = nft.tokenURI(1);
        assertEq(uri, "ipfs://collection_base/1");
    }
}
