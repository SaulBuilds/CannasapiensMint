// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./CannaSapiens.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @title CreativeFlowStateMachine
 * @notice Factory that deploys CannaSapiens contracts using CREATE2.
 *         Manages a 3-phase whitelist, pricing, pause controls, 
 *         supply reveal, and withdrawal of funds.
 */
contract CreativeFlowStateMachine is Ownable(msg.sender), ReentrancyGuard {
    using Address for address payable;

    enum Phase {
        PHASE_1,
        PHASE_2,
        PHASE_3,
        NONE
    }

    Phase public currentPhase;
    bool public factoryPaused;

    bytes32 public merkleRootPhase1;
    bytes32 public merkleRootPhase2;
    bytes32 public merkleRootPhase3;

    uint256 public pricePhase1;
    uint256 public pricePhase2;
    uint256 public pricePhase3;

    mapping(uint256 => address) public contracts;
    uint256 public contractCount;

    event PhaseChanged(Phase newPhase);
    event MerkleRootChanged(Phase phase, bytes32 newRoot);
    event PriceChanged(Phase phase, uint256 newPrice);
    event FactoryPaused(bool isPaused);
    event ContractDeployed(uint256 indexed contractId, address contractAddress, string name, string symbol);
    event SupplyRevealed(uint256 indexed contractId, uint256 maxSupply);
    event ContractPausedStateChanged(uint256 indexed contractId, bool paused);
    event Withdrawn(address indexed to, uint256 amount);

    error InvalidPhase();
    error NotWhitelisted();
    error IncorrectETHSent();
    error ContractPausedError();
    error InvalidContractId();

    modifier whenFactoryNotPaused() {
        if (factoryPaused) revert ContractPausedError();
        _;
    }

    constructor() {
        currentPhase = Phase.NONE;
    }

    function mint(
        string calldata name,
        string calldata symbol,
        bytes32[] calldata proof,
        bytes32 salt
    ) external payable nonReentrant whenFactoryNotPaused {
        (uint256 requiredPrice, bytes32 root) = _currentPhaseData();
        if (msg.value != requiredPrice) revert IncorrectETHSent();
        if (!MerkleProof.verify(proof, root, keccak256(abi.encodePacked(msg.sender)))) revert NotWhitelisted();

        address newContract = _deployCannaSapiens(name, symbol, salt);
        contractCount++;
        contracts[contractCount] = newContract;

        emit ContractDeployed(contractCount, newContract, name, symbol);
    }

    function revealSupply(uint256 contractId) external onlyOwner {
        address child = contracts[contractId];
        if (child == address(0)) revert InvalidContractId();

        uint256 randomValue = uint256(keccak256(
            abi.encodePacked(child, block.timestamp, block.prevrandao, contractId)
        )) % 6666 + 1;

        CannaSapiens(child).setMaxSupply(randomValue);
        emit SupplyRevealed(contractId, randomValue);
    }

    function setChildContractPaused(uint256 contractId, bool paused) external onlyOwner {
        address child = contracts[contractId];
        if (child == address(0)) revert InvalidContractId();
        CannaSapiens(child).setPaused(paused);
        emit ContractPausedStateChanged(contractId, paused);
    }

    function setFactoryPaused(bool _paused) external onlyOwner {
        factoryPaused = _paused;
        emit FactoryPaused(_paused);
    }

    function pauseAllContracts(bool _paused) external onlyOwner {
        for (uint256 i = 1; i <= contractCount; i++) {
            address child = contracts[i];
            if (child != address(0)) {
                CannaSapiens(child).setPaused(_paused);
                emit ContractPausedStateChanged(i, _paused);
            }
        }
    }

    function setChildBaseURI(uint256 contractId, string calldata baseURI) external onlyOwner {
        address child = contracts[contractId];
        if (child == address(0)) revert InvalidContractId();
        CannaSapiens(child).setBaseURI(baseURI);
    }

    function setPhase(Phase phase) external onlyOwner {
        currentPhase = phase;
        emit PhaseChanged(phase);
    }

    function setMerkleRoot(Phase phase, bytes32 root) external onlyOwner {
        if (phase == Phase.PHASE_1) merkleRootPhase1 = root;
        else if (phase == Phase.PHASE_2) merkleRootPhase2 = root;
        else if (phase == Phase.PHASE_3) merkleRootPhase3 = root;
        else revert InvalidPhase();

        emit MerkleRootChanged(phase, root);
    }

    function setPrice(Phase phase, uint256 price) external onlyOwner {
        if (phase == Phase.PHASE_1) pricePhase1 = price;
        else if (phase == Phase.PHASE_2) pricePhase2 = price;
        else if (phase == Phase.PHASE_3) pricePhase3 = price;
        else revert InvalidPhase();

        emit PriceChanged(phase, price);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdraw failed");
        emit Withdrawn(owner(), balance);
    }

    function _deployCannaSapiens(
        string calldata name,
        string calldata symbol,
        bytes32 salt
    ) internal returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(CannaSapiens).creationCode,
            abi.encode(name, symbol, address(this))
        );
        address newContract;
        assembly {
            newContract := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(newContract != address(0), "CREATE2 failed");
        return newContract;
    }

    function _currentPhaseData() internal view returns (uint256, bytes32) {
        if (currentPhase == Phase.PHASE_1) return (pricePhase1, merkleRootPhase1);
        if (currentPhase == Phase.PHASE_2) return (pricePhase2, merkleRootPhase2);
        if (currentPhase == Phase.PHASE_3) return (pricePhase3, merkleRootPhase3);
        revert InvalidPhase();
    }

    receive() external payable {}
}
