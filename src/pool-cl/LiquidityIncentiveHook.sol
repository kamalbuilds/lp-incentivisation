// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PoolKey } from "pancake-v4-core/src/types/PoolKey.sol";
import { BalanceDelta, toBalanceDelta } from "pancake-v4-core/src/types/BalanceDelta.sol";
import { ICLPoolManager } from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import { CLBaseHook } from "./CLBaseHook.sol";
import { BrevisApp } from "./BrevisApp.sol";

contract LiquidityIncentiveHook is CLBaseHook, BrevisApp {
    using SafeMath for uint256;

    struct LiquidityInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockupTime;
        uint256 rewardMultiplier;
        uint256 lastMilestoneTime;
        bool crossPlatformEligible;
    }

    mapping(address => LiquidityInfo) public liquidityProviders;
    bytes32 public vkHash; // Verifying key hash used for proof validation

    event LiquidityAdded(address indexed sender, uint256 amount0, uint256 amount1, uint256 timestamp);
    event LiquidityRemoved(address indexed sender, uint256 amount0, uint256 amount1, uint256 timestamp);
    event RewardGranted(address indexed provider, uint256 rewardAmount, uint256 timestamp);
    
    constructor(
        ICLPoolManager _poolManager, 
        address _brevisRequest
    ) CLBaseHook(_poolManager) BrevisApp(_brevisRequest) {}

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterAddLiquidityReturnsDelta: false,
                afterRemoveLiquidityReturnsDelta: true
            })
        );
    }

    // Handles incentives upon adding liquidity
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override poolManagerOnly returns (bytes4, BalanceDelta) {
        uint256 liquidityAmount = delta.amount0().add(delta.amount1());

        liquidityProviders[sender] = LiquidityInfo({
            amount: liquidityAmount,
            startTime: block.timestamp,
            lockupTime: params.lockupTime,
            rewardMultiplier: calculateRewardMultiplier(params),
            lastMilestoneTime: block.timestamp,
            crossPlatformEligible: checkCrossPlatformEligibility(sender)
        });

        emit LiquidityAdded(sender, delta.amount0(), delta.amount1(), block.timestamp);

        return (this.afterAddLiquidity.selector, delta);
    }

    // Reward calculation based on provided requirements
    function calculateRewardMultiplier(ICLPoolManager.ModifyLiquidityParams calldata params)
        internal
        returns (uint256)
    {
        uint256 multiplier = 1;

        // Time-based reward: Reward based on the duration of liquidity provision
        if (block.timestamp.sub(liquidityProviders[msg.sender].startTime) > 30 days) {
            multiplier = multiplier.add(1); // Add bonus after 30 days
        }

        // Utility-based reward: Apply bonuses during volatile or low liquidity periods using Brevis proof
        if (isLowLiquidityPeriod()) {
            multiplier = multiplier.add(2); // Double bonus during low liquidity
        }

        // Amount-based reward: Increase multiplier for larger contributions
        if (params.amount0.add(params.amount1) > 100 ether) {
            multiplier = multiplier.add(3); // Significant bonus for large contributions
        }

        // Boosted rewards for lockup duration
        if (params.lockupTime > 30 days) {
            multiplier = multiplier.add(params.lockupTime.div(30 days)); // Add a multiplier based on months locked
        }

        return multiplier;
    }

    // Utilize Brevis proof to determine low liquidity periods
    function isLowLiquidityPeriod() internal returns (bool) {
        // Request proof from Brevis for liquidity and volatility data
        requestBrevisProof("liquidity", "volatility");
        return true; // Placeholder: Actual verification handled in callback
    }

    // Callback function to handle proof results from Brevis
    function handleProofResult(
        bytes32 /*_requestId*/,
        bytes32 _vkHash,
        bytes calldata _circuitOutput
    ) internal override {
        // Verify the proof using the designated verifying key
        require(vkHash == _vkHash, "Invalid verifying key");

        // Decode the circuit output to extract liquidity and volatility data
        (uint256 liquidityLevel, uint256 volatilityLevel) = decodeOutput(_circuitOutput);

        // Example condition for adjusting rewards based on data
        if (liquidityLevel < 1000 && volatilityLevel > 75) {
            // Adjust rewards based on detected conditions
            emit RewardGranted(msg.sender, 100, block.timestamp); // Example reward adjustment
        }
    }

    // Decodes the Brevis circuit output to extract data
    function decodeOutput(bytes calldata output) internal pure returns (uint256, uint256) {
        uint256 liquidityLevel = uint256(bytes32(output[0:32]));
        uint256 volatilityLevel = uint256(bytes32(output[32:64]));
        return (liquidityLevel, volatilityLevel);
    }

    function checkCrossPlatformEligibility(address sender) internal returns (bool) {
        // Cross-platform reward validation via Brevis or other integrations
        return true; // Placeholder
    }

    // Milestone and penalty logic when removing liquidity
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override poolManagerOnly returns (bytes4, BalanceDelta) {
        LiquidityInfo storage info = liquidityProviders[sender];

        // Milestone reward validation
        if (block.timestamp >= info.lastMilestoneTime.add(7 days)) {
            grantMilestoneRewards(sender, info);
        }

        // Penalty for breaking lockup period
        if (block.timestamp < info.startTime.add(info.lockupTime)) {
            uint256 penalty = calculateEarlyWithdrawalPenalty(info);
            delta = applyPenalty(delta, penalty);
        }

        emit LiquidityRemoved(sender, delta.amount0(), delta.amount1(), block.timestamp);
        return (this.afterRemoveLiquidity.selector, delta);
    }

    function grantMilestoneRewards(address sender, LiquidityInfo storage info) internal {
        uint256 reward = info.amount.mul(info.rewardMultiplier);
        info.lastMilestoneTime = block.timestamp;
        emit RewardGranted(sender, reward, block.timestamp);
    }

    function calculateEarlyWithdrawalPenalty(LiquidityInfo memory info) internal pure returns (uint256) {
        return info.amount.mul(10).div(100); // 10% penalty
    }

    function applyPenalty(BalanceDelta memory delta, uint256 penalty) internal pure returns (BalanceDelta) {
        delta.amount0 = delta.amount0.sub(penalty);
        delta.amount1 = delta.amount1.sub(penalty);
        return delta;
    }
}

 /**
     * @notice config params to handle optimitic proof result
     * @param _challengeWindow The challenge window to accept optimistic result. 0: POS, maxInt: disable optimistic result
     * @param _sigOption bitmap to express expected sigs: bit 0 is bvn, bit 1 is avs
     */
    function setBrevisOpConfig(uint64 _challengeWindow, uint8 _sigOption) external onlyOwner {
        brevisOpConfig = BrevisOpConfig(_challengeWindow, _sigOption);
    }

    
    // vkHash represents the unique circuit app logic
    function setVkHash(bytes32 _vkHash) external onlyOwner {
        vkHash = _vkHash;
    }
