// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TreasuryVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public multisig;

    event DepositReceived(address indexed token, address indexed from, uint256 amount);
    event WithdrawalExecuted(address indexed token, address indexed to, uint256 amount);
    event MultisigUpdated(address indexed newMultisig);

    constructor(address _multisig) {
        require(_multisig != address(0), "Vault: zero multisig");
        multisig = _multisig;
        emit MultisigUpdated(_multisig);
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == multisig, "Vault: not authorized");
        _;
    }

    // ERC20 deposit
    function deposit(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Vault: zero amount");
        require(token != address(0), "Vault: zero token");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit DepositReceived(token, msg.sender, amount);
    }

    // Native ETH deposit
    receive() external payable {
        emit DepositReceived(address(0), msg.sender, msg.value);
    }

    function withdraw(address token, address to, uint256 amount) external onlyAdmin nonReentrant {
        require(amount > 0, "Vault: zero amount");
        require(token != address(0), "Vault: zero token");
        require(to != address(0), "Vault: zero recipient");
        IERC20(token).safeTransfer(to, amount);
        emit WithdrawalExecuted(token, to, amount);
    }

    function withdrawETH(address to, uint256 amount) external onlyAdmin nonReentrant {
        require(to != address(0), "Vault: zero recipient");
        require(amount <= address(this).balance, "Vault: insufficient ETH");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Vault: ETH withdraw failed");
        emit WithdrawalExecuted(address(0), to, amount);
    }

    function setMultisig(address _newMultisig) external onlyOwner {
        require(_newMultisig != address(0), "Vault: zero multisig");
        multisig = _newMultisig;
        emit MultisigUpdated(_newMultisig);
    }

    function balanceOf(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }
}
