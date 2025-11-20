// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {InstallmentLogic} from "./InstallmentLogic.sol";

interface IEscrowManager {
    function lockAsset(address nft, uint256 tokenId) external;
    function releaseAsset(address nft, uint256 tokenId, address to) external;
    function forfeitAsset(address nft, uint256 tokenId, address to) external;
}

contract LoanModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using InstallmentLogic for InstallmentLogic.InstallmentPlan;
    
    IERC721 public nft;
    IERC20 public token;
    IEscrowManager public escrow;
    address public treasury;
    uint256 public interestRateBps; // e.g., 500 = 5%

    struct Loan {
        address borrower;
        uint256 principal;
        uint256 totalRepayable;
        uint256 paid;
        uint256 createdAt;
        uint256 deadline;
        bool active;
    }

    mapping(uint256 => Loan) public loans;
    mapping(uint256 => InstallmentLogic.InstallmentPlan) public installments;

    uint256 public loanDuration = 30 days;
    uint8 public maxInstallments = 4;

    event LoanRequested(uint256 tokenId, address borrower, uint256 amount);
    event Repaid(uint256 tokenId, address borrower, uint256 amount);
    event Liquidated(uint256 tokenId, address liquidator);

    constructor(address _nft, address _token, address _escrow) {
        nft = IERC721(_nft);
        token = IERC20(_token);
        escrow = IEscrowManager(_escrow);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
    }

    function requestLoan(uint256 tokenId, uint256 amount) external nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(amount > 0, "Invalid amount");
        require(!loans[tokenId].active, "Loan exists");
        require(treasury != address(0), "Treasury not set");

        // Lock NFT into escrow
        nft.transferFrom(msg.sender, address(escrow), tokenId);
        escrow.lockAsset(address(nft), tokenId);

        // Compute total repayable = principal + interest
        uint256 interest = (amount * interestRateBps) / 10_000;
        uint256 totalRepayable = amount + interest;

        loans[tokenId] = Loan({
            borrower: msg.sender,
            principal: amount,
            totalRepayable: totalRepayable,
            paid: 0,
            createdAt: block.timestamp,
            deadline: block.timestamp + loanDuration,
            active: true
        });

        // Derive per-installment interval from total duration and count
        uint256 interval = loanDuration / maxInstallments;
        if (interval == 0) {
            // Fallback to at least 1 day to avoid zero interval
            interval = 1 days;
        }
        // First installment due after one interval
        installments[tokenId] = InstallmentLogic.createPlan(
            totalRepayable,
            maxInstallments,
            block.timestamp + interval,
            interval
        );

        // Send loan tokens to borrower from treasury (treasury must approve this contract)
        require(token.balanceOf(treasury) >= amount, "Treasury insufficient");
        token.safeTransferFrom(treasury, msg.sender, amount);

        emit LoanRequested(tokenId, msg.sender, amount);
    }

    function repayLoan(uint256 tokenId, uint256 amount) external nonReentrant {
        Loan storage loan = loans[tokenId];
        require(loan.active, "No active loan");
        require(msg.sender == loan.borrower, "Not borrower");

        // Pull repayment to treasury BEFORE state updates
        token.safeTransferFrom(msg.sender, treasury, amount);

        InstallmentLogic.InstallmentPlan storage plan = installments[tokenId];
        (uint256 remaining, ) = plan.payInstallment(amount, block.timestamp);

        loan.paid += amount;

        emit Repaid(tokenId, msg.sender, amount);

        if (remaining == 0) {
            loan.active = false;
            escrow.releaseAsset(address(nft), tokenId, loan.borrower);
        }
    }

    function liquidateLoan(uint256 tokenId) external nonReentrant {
        Loan storage loan = loans[tokenId];
        require(loan.active, "Loan inactive");
        require(block.timestamp > loan.deadline, "Loan not expired");

        loan.active = false;
        address recipient = treasury != address(0) ? treasury : owner();
        escrow.forfeitAsset(address(nft), tokenId, recipient);

        emit Liquidated(tokenId, msg.sender);
    }

    function getInstallmentStatus(uint256 tokenId) external view returns (uint256 remaining, bool defaulted) {
        InstallmentLogic.InstallmentPlan storage plan = installments[tokenId];
        remaining = plan.getRemaining();
        defaulted = InstallmentLogic.isDefaulted(plan, block.timestamp);
    }

    function setLoanDuration(uint256 duration) external onlyOwner {
        loanDuration = duration;
    }

    function setInterestRate(uint256 bps) external onlyOwner {
        require(bps <= 5000, "Rate too high");
        interestRateBps = bps;
    }

    // Admin rescue functions
    function rescueERC20(address erc20, uint256 amount, address to) external onlyOwner {
        IERC20(erc20).transfer(to, amount);
    }

    function rescueERC721(address erc721, uint256 tokenId, address to) external onlyOwner {
        IERC721(erc721).transferFrom(address(this), to, tokenId);
    }

    function setMaxInstallments(uint8 num) external onlyOwner {
        maxInstallments = num;
    }
}
