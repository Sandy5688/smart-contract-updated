// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public mfh;

    event RewardSent(address indexed user, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address _mfh) {
        mfh = IERC20(_mfh);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        mfh = IERC20(_token);
    }

    function distribute(address[] calldata users, uint256[] calldata amounts) external onlyOwner nonReentrant {
        require(users.length == amounts.length, "Mismatched arrays");

        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }

        require(mfh.balanceOf(address(this)) >= total, "Insufficient funds");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Zero address recipient");
            // WARNING: Batches >200–300 recipients may hit block gas limit. Split large distributions.
            mfh.safeTransfer(users[i], amounts[i]);
            emit RewardSent(users[i], amounts[i]);
        }
    }

    function withdrawLeftover(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Zero recipient");
        require(amount <= mfh.balanceOf(address(this)), "Insufficient balance");
        mfh.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }
}
