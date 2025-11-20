// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract StakingRewards is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private stakers;

    IERC20 public token;

    uint256 public totalStaked;
    uint256 public rewardRate; // tokens per second
    uint256 public lastUpdateTime;
    uint256 public accRewardPerToken; // scaled by 1e18
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public penaltyPercent = 10; // 10%
    bool public penaltyEnabled = false;
    uint256 public penaltyWindow = 7 days;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt; // amount * accRewardPerToken / ACC_PRECISION
        uint256 lastStaked; // timestamp of last stake (for penalty window)
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event PenaltyApplied(address indexed user, uint256 amount);
    event Funded(uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
    }

    function fundRewards(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Zero amount");
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(amount);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Stake: zero amount");
        _updatePool();
        token.safeTransferFrom(msg.sender, address(this), amount);

        StakeInfo storage user = stakes[msg.sender];
        if (user.amount > 0) {
            uint256 pending = _pendingRewards(msg.sender);
            if (pending > 0) {
                uint256 payout = _applyPenaltyIfNeeded(msg.sender, pending);
                require(token.balanceOf(address(this)) >= payout, "Insufficient rewards");
                token.safeTransfer(msg.sender, payout);
                emit RewardClaimed(msg.sender, payout);
            }
        }

        user.amount += amount;
        user.lastStaked = block.timestamp;
        user.rewardDebt = (user.amount * accRewardPerToken) / ACC_PRECISION;
        stakers.add(msg.sender); // Add to active set

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        StakeInfo storage user = stakes[msg.sender];
        require(user.amount > 0, "Unstake: nothing staked");
        if (amount == 0 || amount > user.amount) {
            amount = user.amount; // full unstake by default
        }

        _updatePool();
        uint256 pending = _pendingRewards(msg.sender);
        uint256 payout = _applyPenaltyIfNeeded(msg.sender, pending);

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerToken) / ACC_PRECISION;
        if (user.amount == 0) {
            stakers.remove(msg.sender);
        }

        // Transfer principal + rewards in one go
        uint256 transferOut = amount + payout;
        require(token.balanceOf(address(this)) >= transferOut, "Insufficient balance");
        token.safeTransfer(msg.sender, transferOut);

        emit Unstaked(msg.sender, amount, payout);
    }

    function claimReward() external nonReentrant {
        _updatePool();
        uint256 pending = _pendingRewards(msg.sender);
        uint256 payout = _applyPenaltyIfNeeded(msg.sender, pending);

        if (payout > 0) {
            stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardPerToken) / ACC_PRECISION;
            require(token.balanceOf(address(this)) >= payout, "Insufficient rewards");
            token.safeTransfer(msg.sender, payout);
            emit RewardClaimed(msg.sender, payout);
        } else {
            stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardPerToken) / ACC_PRECISION;
        }
    }

    function _pendingRewards(address userAddr) internal view returns (uint256) {
        StakeInfo memory s = stakes[userAddr];
        if (s.amount == 0) return 0;

        uint256 acc = accRewardPerToken;
        if (totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            acc += (timeElapsed * rewardRate * ACC_PRECISION) / totalStaked;
        }
        uint256 accumulated = (s.amount * acc) / ACC_PRECISION;
        if (accumulated < s.rewardDebt) return 0;
        return accumulated - s.rewardDebt;
    }

    function pendingRewards(address userAddr) external view returns (uint256) {
        return _pendingRewards(userAddr);
    }

    function setRewardRate(uint256 rate) external onlyOwner {
        _updatePool();
        rewardRate = rate;
        emit RewardRateUpdated(rate);
    }

    function setPenaltyPercent(uint256 percent) external onlyOwner {
        require(percent <= 100, "Penalty too high");
        penaltyPercent = percent;
    }

    function setPenaltyEnabled(bool enabled) external onlyOwner {
        penaltyEnabled = enabled;
    }

    function setPenaltyWindow(uint256 window) external onlyOwner {
        penaltyWindow = window;
    }

    function getEligibleAddresses() external view returns (address[] memory) {
        uint256 length = stakers.length();
        address[] memory result = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = stakers.at(i);
        }
        return result;
    }

    function emergencyWithdraw() external nonReentrant {
        StakeInfo storage user = stakes[msg.sender];
        uint256 amount = user.amount;
        require(amount > 0, "Nothing staked");
        totalStaked -= amount;
        user.amount = 0;
        user.rewardDebt = 0;
        stakers.remove(msg.sender);
        token.safeTransfer(msg.sender, amount);
        // no rewards paid
    }

    function _updatePool() internal {
        if (lastUpdateTime == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed > 0) {
            accRewardPerToken += (timeElapsed * rewardRate * ACC_PRECISION) / totalStaked;
            lastUpdateTime = block.timestamp;
        }
    }

    function _applyPenaltyIfNeeded(address userAddr, uint256 reward) internal returns (uint256 payout) {
        payout = reward;
        if (reward == 0) return payout;
        if (!penaltyEnabled) return payout;
        StakeInfo memory s = stakes[userAddr];
        if (block.timestamp < s.lastStaked + penaltyWindow) {
            uint256 penalty = (reward * penaltyPercent) / 100;
            payout = reward - penalty;
            emit PenaltyApplied(userAddr, penalty);
        }
    }
}
