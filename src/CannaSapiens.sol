// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title CannaSapiens
 * @notice ERC721 contract deployed by CreativeFlowStateMachine.
 *         It supports pausing, setting max supply (once revealed),
 *         and updating base URI. Minting is controlled by factory.
 */
contract CannaSapiens is ERC721, ReentrancyGuard {
    using Strings for uint256;

    address public immutable factory;
    uint256 public maxSupply;
    uint256 public currentTokenId;
    string private baseTokenURI;
    bool public paused;

    error NotFactory();
    error PausedContract();
    error MaxSupplyNotSet();
    error ExceedsMaxSupply();
    error Unauthorized();

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedContract();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _factory
    ) ERC721(_name, _symbol) {
        factory = _factory;
        paused = true; 
    }

    /**
     * @notice Mint a new token.
     */
    function mint(address to) external whenNotPaused nonReentrant {
        if (maxSupply == 0) revert MaxSupplyNotSet();
        if (currentTokenId >= maxSupply) revert ExceedsMaxSupply();

        currentTokenId++;
        _safeMint(to, currentTokenId);
    }

    /**
     * @notice Set max supply (once), only by factory.
     */
    function setMaxSupply(uint256 _maxSupply) external onlyFactory {
        if (maxSupply != 0) revert Unauthorized();
        maxSupply = _maxSupply;
    }

    /**
     * @notice Set pause state, only by factory.
     */
    function setPaused(bool _paused) external onlyFactory {
        paused = _paused;
    }

    /**
     * @notice Set base URI, only by factory.
     */
    function setBaseURI(string memory newBaseURI) external onlyFactory {
        baseTokenURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @notice Returns the token URI.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory base = _baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString())) : "";
    }
}
