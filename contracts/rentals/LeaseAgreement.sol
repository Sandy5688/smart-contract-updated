// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRentalEngine {
    function registerLease(address lessor, address lessee, uint256 tokenId, uint256 duration) external;
    function forceEndLease(uint256 tokenId) external;
}

contract LeaseAgreement is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC721 public immutable nft;
    IRentalEngine public rentalEngine;
    IERC20 public paymentToken;
    uint256 public leaseFeePerDay;

    event LeaseStarted(address indexed lessor, address indexed lessee, uint256 tokenId, uint256 duration);
    event LeaseEnded(uint256 indexed tokenId, address endedBy);
    event LeaseFeeUpdated(uint256 newFeePerDay);

    constructor(address _nft, address _rentalEngine) {
        nft = IERC721(_nft);
        rentalEngine = IRentalEngine(_rentalEngine);
    }

    function setPaymentToken(address token) external onlyOwner {
        require(token != address(0), "Zero token");
        paymentToken = IERC20(token);
    }

    function setLeaseFeePerDay(uint256 newFee) external onlyOwner {
        leaseFeePerDay = newFee;
        emit LeaseFeeUpdated(newFee);
    }

    function updateRentalEngine(address newEngine) external onlyOwner {
        require(newEngine != address(0), "Zero engine");
        rentalEngine = IRentalEngine(newEngine);
    }

    function startLease(uint256 tokenId, address lessee, uint256 duration) external nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(duration >= 1 days, "Min duration is 1 day");
        require(lessee != address(0), "Zero lessee");

        // Collect upfront fee from lessee to lessor
        if (address(paymentToken) != address(0) && leaseFeePerDay > 0) {
            uint256 daysCount = duration / 1 days;
            uint256 totalFee = daysCount * leaseFeePerDay;
            paymentToken.safeTransferFrom(lessee, msg.sender, totalFee);
        }

        // Transfer to engine escrow (never to lessee)
        nft.safeTransferFrom(msg.sender, address(rentalEngine), tokenId);

        rentalEngine.registerLease(msg.sender, lessee, tokenId, duration);

        emit LeaseStarted(msg.sender, lessee, tokenId, duration);
    }

    function endLease(uint256 tokenId) external onlyOwner nonReentrant {
        rentalEngine.forceEndLease(tokenId);
        emit LeaseEnded(tokenId, msg.sender);
    }
}
