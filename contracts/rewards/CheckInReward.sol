// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CheckInReward is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    IERC20 public token;
    uint256 public rewardAmount;
    mapping(address => uint256) public lastCheckInDay;
    bool public randomBonusEnabled;

    event CheckedIn(address indexed user, uint256 reward);
    event RewardAmountUpdated(uint256 newAmount);
    event TokenUpdated(address newToken);
    event RandomBonusToggled(bool enabled);

    constructor(address _mfh, uint256 _rewardAmount) {
        token = IERC20(_mfh);
        rewardAmount = _rewardAmount;
    }

    function checkIn() external nonReentrant whenNotPaused {
        uint256 day = block.timestamp / 1 days;
        require(lastCheckInDay[msg.sender] < day, "Already checked in today");
        lastCheckInDay[msg.sender] = day;

        require(token.balanceOf(address(this)) >= rewardAmount, "Out of rewards");
        uint256 payout = rewardAmount;
        // Optional simple pseudo-bonus (not secure randomness; off-chain or VRF recommended)
        if (randomBonusEnabled && (uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp))) % 10 == 0)) {
            payout = (rewardAmount * 110) / 100; // +10% bonus
            require(token.balanceOf(address(this)) >= payout, "Insufficient bonus funds");
        }
        token.safeTransfer(msg.sender, payout);

        emit CheckedIn(msg.sender, payout);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
        emit TokenUpdated(_token);
    }

    function setRewardAmount(uint256 _amount) external onlyOwner {
        rewardAmount = _amount;
        emit RewardAmountUpdated(_amount);
    }

    function toggleRandomBonus(bool enabled) external onlyOwner {
        randomBonusEnabled = enabled;
        emit RandomBonusToggled(enabled);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function emergencyWithdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Zero recipient");
        token.safeTransfer(to, amount);
    }

    function currentDay() external view returns (uint256) {
        return block.timestamp / 1 days;
    }
}
