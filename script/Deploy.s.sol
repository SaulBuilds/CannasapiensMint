// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "../src/CreativeFlowStateMachine.sol";

/**
 * @notice Simple deployment script for CreativeFlowStateMachine
 *         Run: forge script script/Deploy.s.sol --broadcast
 */
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        CreativeFlowStateMachine factory = new CreativeFlowStateMachine();

        // Set initial phase prices
        factory.setPrice(CreativeFlowStateMachine.Phase.PHASE_1, 0.01 ether);
        factory.setPrice(CreativeFlowStateMachine.Phase.PHASE_2, 0.02 ether);
        factory.setPrice(CreativeFlowStateMachine.Phase.PHASE_3, 0.03 ether);

        // Set current phase
        factory.setPhase(CreativeFlowStateMachine.Phase.PHASE_1);

        // You can also set merkle roots, pause state, etc. here if desired
        vm.stopBroadcast();
    }
}
