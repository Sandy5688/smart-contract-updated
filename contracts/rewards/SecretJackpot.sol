// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IStakingRewards {
    function getEligibleAddresses() external view returns (address[] memory);
}

contract SecretJackpot is VRFConsumerBase, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 internal keyHash;
    uint256 internal fee;

    IStakingRewards public stakingContract;
    uint256 public jackpotAmount;
    address public paymentToken;
    uint256 public lastJackpotTimestamp;
    uint256 public cooldownPeriod = 1 days;

    event JackpotRequested(uint256 requestId);
    event JackpotWon(address winner, uint256 amount);
    event EligibilityRulesUpdated(uint256 cooldownPeriod, uint256 jackpotAmount);
    event StakingContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event JackpotFundDeposited(address from, uint256 amount);

    constructor(
        address _stakingRewards,
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address _paymentToken,
        uint256 _jackpotAmount
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        stakingContract = IStakingRewards(_stakingRewards);
        keyHash = _keyHash;
        fee = _fee;
        paymentToken = _paymentToken;
        jackpotAmount = _jackpotAmount;
    }

    modifier onlyCooldownPassed() {
        require(block.timestamp >= lastJackpotTimestamp + cooldownPeriod, "Cooldown not met");
        _;
    }

    function triggerJackpot() external onlyCooldownPassed returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        require(IERC20(paymentToken).balanceOf(address(this)) >= jackpotAmount, "Insufficient jackpot funds");

        lastJackpotTimestamp = block.timestamp;
        requestId = requestRandomness(keyHash, fee);
        emit JackpotRequested(uint256(requestId));
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        address[] memory eligible = stakingContract.getEligibleAddresses();
        require(eligible.length > 0, "No eligible users");
        uint256 winnerIndex = randomness % eligible.length;
        address winner = eligible[winnerIndex];

        require(IERC20(paymentToken).balanceOf(address(this)) >= jackpotAmount, "Insufficient funds");
        IERC20(paymentToken).safeTransfer(winner, jackpotAmount);

        emit JackpotWon(winner, jackpotAmount);
    }

    // ----------------------------
    // Admin functions
    // ----------------------------

    function setEligibilityRules(uint256 _cooldown, uint256 _amount) external onlyOwner {
        require(_cooldown > 0, "Cooldown must be > 0");
        require(_amount > 0, "Jackpot amount must be > 0");
        cooldownPeriod = _cooldown;
        jackpotAmount = _amount;
        emit EligibilityRulesUpdated(_cooldown, _amount);
    }

    function setStakingContract(address _staking) external onlyOwner {
        stakingContract = IStakingRewards(_staking);
        emit StakingContractUpdated(_staking);
    }

    function setToken(address _token) external onlyOwner {
        paymentToken = _token;
        emit PaymentTokenUpdated(_token);
    }

    function withdrawLINK(address to) external onlyOwner nonReentrant {
        uint256 balance = LINK.balanceOf(address(this));
        require(LINK.transfer(to, balance), "LINK withdrawal failed");
    }

    function depositJackpotFunds(uint256 amount) external nonReentrant {
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        emit JackpotFundDeposited(msg.sender, amount);
    }
}
