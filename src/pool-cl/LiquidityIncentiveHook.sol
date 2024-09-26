// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./CLBaseHook.sol";

contract LiquidityIncentiveHook is CLBaseHook {
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
    LayerZeroInterface public layerZero;

    event LiquidityAdded(address indexed sender, uint256 amount0, uint256 amount1, uint256 timestamp);
    event LiquidityRemoved(address indexed sender, uint256 amount0, uint256 amount1, uint256 timestamp);
    event RewardGranted(address indexed provider, uint256 rewardAmount, uint256 timestamp);
    
    constructor(ICLPoolManager _poolManager, LayerZeroInterface _layerZero) CLBaseHook(_poolManager) {
        layerZero = _layerZero;
    }

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
        view
        returns (uint256)
    {
        uint256 multiplier = 1;

        // Time-based reward: Reward based on the duration of liquidity provision
        if (block.timestamp.sub(liquidityProviders[msg.sender].startTime) > 30 days) {
            multiplier = multiplier.add(1); // Add bonus after 30 days
        }

        // Utility-based reward: Apply bonuses during volatile or low liquidity periods
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

    function isLowLiquidityPeriod() internal view returns (bool) {
        // will implement the  detection logic based on brevis market data
        return true; // @kamal to be updated with actual market checks
    }

   // to be implemented in the future @kamal , i think i will utilise brevis here instead of lz
    function checkCrossPlatformEligibility(address sender) internal returns (bool) {
        // Cross-platform reward validation via LayerZero or other integrations
        // Communicate and validate cross-chain data (simplified for demo)
        return layerZero.validateLiquidity(sender);
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
        // @kamal Logic for distributing rewards
    }

    function calculateEarlyWithdrawalPenalty(LiquidityInfo memory info) internal pure returns (uint256) {
        // Penalty calculation based on early withdrawal
        return info.amount.mul(10).div(100); // 10% penalty
    }

    function applyPenalty(BalanceDelta memory delta, uint256 penalty) internal pure returns (BalanceDelta) {
        delta.amount0 = delta.amount0.sub(penalty);
        delta.amount1 = delta.amount1.sub(penalty);
        return delta;
    }
}
